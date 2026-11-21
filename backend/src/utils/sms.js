// SMS sending via Fast2SMS (DLT route). Credentials come from .env only — never commit them.
//   FAST2SMS_API_KEY      authorization key from the Fast2SMS dashboard
//   FAST2SMS_SENDER_ID    DLT-approved sender id, e.g. CITGDN
//   FAST2SMS_TEMPLATE_ID  DLT message/template id, e.g. 199510 (template must have one {#var#} for the OTP)
const { ApiError } = require('./helpers');

const isSmsConfigured = () => Boolean(process.env.FAST2SMS_API_KEY && process.env.FAST2SMS_SENDER_ID && process.env.FAST2SMS_TEMPLATE_ID);

async function sendOtpSms(phone, otp) {
  if (!isSmsConfigured()) {
    console.log(`[OTP] SMS not configured — ${phone} -> ${otp}`);
    return { sent: false };
  }
  const params = new URLSearchParams({
    authorization: process.env.FAST2SMS_API_KEY,
    route: 'dlt',
    sender_id: process.env.FAST2SMS_SENDER_ID,
    message: process.env.FAST2SMS_TEMPLATE_ID,
    variables_values: `${otp}|`,
    flash: '0',
    numbers: phone,
  });
  let data;
  try {
    const res = await fetch(`https://www.fast2sms.com/dev/bulkV2?${params}`, { signal: AbortSignal.timeout(15000) });
    data = await res.json().catch(() => ({}));
  } catch (e) {
    console.error('[OTP] Fast2SMS request failed:', e.message);
    throw new ApiError(502, 'Could not send OTP right now. Please try again.');
  }
  if (data && data.return === true) return { sent: true, requestId: data.request_id };
  const reason = Array.isArray(data?.message) ? data.message.join(', ') : data?.message || 'Unknown error';
  console.error('[OTP] Fast2SMS error:', reason);
  throw new ApiError(502, `Failed to send OTP: ${reason}`);
}

module.exports = { sendOtpSms, isSmsConfigured };
