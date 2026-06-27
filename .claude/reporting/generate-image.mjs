#!/usr/bin/env node
// generate-image.mjs — image generator for the `/report` `illustrated` style.
//
// Zero dependencies: Node 18+ built-ins only (global fetch, node:fs, node:path). No npm install.
//
// Provider is kie.ai's unified Jobs API by default, but everything is configurable via env so the
// vendor is not hardcoded:
//   KIE_API_KEY    (required)  — Bearer token; lives in the environment, NEVER committed.
//   KIE_BASE_URL   (optional)  — default https://api.kie.ai
//   KIE_MODEL_T2I  (optional)  — default google/nano-banana        (text-to-image)
//   KIE_MODEL_I2I  (optional)  — default google/nano-banana-edit   (image-to-image / restyle)
//
// Usage:
//   node generate-image.mjs --prompt "modern minimal cover, deep blue" --out docs/reports/assets/2026-06-27/cover.png
//   node generate-image.mjs --prompt "redraw in hand-drawn ink style" --image-url https://host/diagram.png --out .../arch.png
//
// When --image-url is given, the image-to-image model is used so an already-rendered diagram is
// RESTYLED (topology preserved), never invented. See the report SKILL §3b correctness guard.
//
// Docs: https://docs.kie.ai/market/google/nano-banana · /nano-banana-edit · /market/common/get-task-detail

import { writeFile, mkdir, readFile } from 'node:fs/promises'
import { basename, dirname } from 'node:path'

const BASE = process.env.KIE_BASE_URL ?? 'https://api.kie.ai'
const UPLOAD_URL = process.env.KIE_UPLOAD_URL ?? `${BASE}/api/file-base64-upload`
const KEY = process.env.KIE_API_KEY
const MODEL_T2I = process.env.KIE_MODEL_T2I ?? 'google/nano-banana'
const MODEL_I2I = process.env.KIE_MODEL_I2I ?? 'google/nano-banana-edit'

function arg(name, fallback = undefined) {
  const i = process.argv.indexOf(`--${name}`)
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : fallback
}

const prompt = arg('prompt')
const out = arg('out')
let imageUrl = arg('image-url')          // already-hosted reference → triggers image-to-image restyle
const imageFile = arg('image-file')      // local reference PNG → uploaded first, then restyled
const aspect = arg('aspect', '16:9')      // slide default
const format = arg('format', 'png')
const timeoutMs = Number(arg('timeout', '180000'))
const pollMs = Number(arg('poll', '4000'))

function die(msg) { console.error(`✗ ${msg}`); process.exit(1) }

if (!KEY) die('KIE_API_KEY is not set in the environment. Export it; never commit it.')
if (!prompt) die('--prompt is required.')
if (!out) die('--out <path> is required.')

const headers = { Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' }

// Upload a local reference PNG and return its public URL, so nano-banana-edit can restyle it.
async function uploadLocal(path) {
  const data = await readFile(path).catch(() => die(`Cannot read --image-file ${path}`))
  const body = { base64Data: data.toString('base64'), uploadPath: 'report-refs', fileName: basename(path) }
  const res = await fetch(UPLOAD_URL, { method: 'POST', headers, body: JSON.stringify(body) })
  const json = await res.json().catch(() => ({}))
  const url = json.data?.downloadUrl
  if (!res.ok || !url) die(`Reference upload failed (${res.status}): ${json.msg ?? JSON.stringify(json)}`)
  return url
}

async function createTask() {
  const model = imageUrl ? MODEL_I2I : MODEL_T2I
  const input = { prompt, output_format: format, aspect_ratio: aspect }
  if (imageUrl) input.image_urls = [imageUrl]
  const res = await fetch(`${BASE}/api/v1/jobs/createTask`, {
    method: 'POST', headers, body: JSON.stringify({ model, input }),
  })
  const json = await res.json().catch(() => ({}))
  if (!res.ok || json.code !== 200 || !json.data?.taskId) {
    die(`createTask failed (${res.status}): ${json.msg ?? JSON.stringify(json)}`)
  }
  return json.data.taskId
}

async function poll(taskId) {
  const deadline = Date.now() + timeoutMs
  // Date.now() here is fine — this is a runtime CLI script, not a workflow body.
  while (Date.now() < deadline) {
    const res = await fetch(`${BASE}/api/v1/jobs/recordInfo?taskId=${encodeURIComponent(taskId)}`, { headers })
    const json = await res.json().catch(() => ({}))
    const data = json.data ?? {}
    const state = data.state
    if (state === 'success') {
      const result = JSON.parse(data.resultJson ?? '{}')
      const url = result.resultUrls?.[0]
      if (!url) die('Task succeeded but no resultUrls were returned.')
      return url
    }
    if (state === 'fail') die(`Generation failed: ${data.failMsg ?? data.failCode ?? 'unknown'}`)
    process.stdout.write(`  …${state ?? 'pending'}\r`)
    await new Promise(r => setTimeout(r, pollMs))
  }
  die(`Timed out after ${timeoutMs}ms waiting for the image.`)
}

async function download(url, path) {
  const res = await fetch(url)
  if (!res.ok) die(`Could not download result image (${res.status}).`)
  const buf = Buffer.from(await res.arrayBuffer())
  await mkdir(dirname(path), { recursive: true })
  await writeFile(path, buf)
}

if (imageFile && !imageUrl) {
  console.error(`↑ uploading reference ${imageFile}`)
  imageUrl = await uploadLocal(imageFile)
}
console.error(`→ ${imageUrl ? `restyling (image-to-image) via ${MODEL_I2I}` : `generating (text-to-image) via ${MODEL_T2I}`}`)
const taskId = await createTask()
const url = await poll(taskId)
await download(url, out)
console.error(`✓ saved ${out}  [1 image-gen call]`)
