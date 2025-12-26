const sgMail = require('@sendgrid/mail');

/**
 * Send an email via SendGrid if SENDGRID_API_KEY is configured.
 * Returns an object { status: 'sent'|'skipped'|'error', info }
 */
async function sendEmailViaSendGrid({ to, subject, body }) {
  const key = process.env.SENDGRID_API_KEY;
  if (!key) {
    return { status: 'skipped', info: 'SENDGRID_API_KEY not set' };
  }

  try {
    sgMail.setApiKey(key);
    const msg = {
      to,
      from: process.env.FROM_EMAIL || 'noreply@example.com',
      subject,
      text: body,
      html: `<pre>${escapeHtml(body)}</pre>`,
    };
    await sgMail.send(msg);
    return { status: 'sent' };
  } catch (e) {
    return { status: 'error', info: e && e.message ? e.message : String(e) };
  }
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/\"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

module.exports = { sendEmailViaSendGrid };
