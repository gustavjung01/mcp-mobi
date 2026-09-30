import http from 'node:http';

const host = process.env.REPORT_AGENT_HOST || '127.0.0.1';
const port = Number(process.env.REPORT_AGENT_PORT || 4010);
const token = String(process.env.REPORT_AGENT_TOKEN || '').trim();

if (!token) {
  throw new Error('REPORT_AGENT_TOKEN_REQUIRED');
}

function send(res, statusCode, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    send(res, 200, { ok: true });
    return;
  }
  if (req.method !== 'POST' || req.url !== '/analyze') {
    send(res, 404, { ok: false });
    return;
  }
  if (req.headers.authorization !== `Bearer ${token}`) {
    send(res, 401, { ok: false });
    return;
  }

  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  let body;
  try {
    body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    send(res, 400, { ok: false });
    return;
  }
  if (body?.task !== 'mcp_session_report_analysis' || !body?.snapshot) {
    send(res, 422, { ok: false });
    return;
  }

  send(res, 200, {
    ok: true,
    source: 'l7_runtime_test_agent',
    result: {
      summary: 'Phân tích runtime L7 đã hoàn tất.',
      market_insights: ['Runtime market insight'],
      product_insights: ['Runtime product insight'],
      customer_actions: ['Runtime customer action'],
      sample_requests: [],
      follow_up_list: ['Runtime follow-up'],
      order_opportunities: ['Runtime order opportunity'],
      risks: [],
      next_steps: ['Runtime next step'],
    },
  });
});

server.listen(port, host, () => {
  process.stdout.write(JSON.stringify({
    event: 'l7_report_agent_ready',
    host,
    port,
  }) + '\n');
});
