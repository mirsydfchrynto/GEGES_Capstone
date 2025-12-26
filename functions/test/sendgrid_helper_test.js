const { expect } = require('chai');
const { sendEmailViaSendGrid } = require('../sendgrid_helper');

describe('sendgrid_helper', () => {
  it('should return skipped when SENDGRID_API_KEY not set', async () => {
    delete process.env.SENDGRID_API_KEY;
    const res = await sendEmailViaSendGrid({ to: 'x@x.com', subject: 'hi', body: 'test' });
    expect(res).to.have.property('status', 'skipped');
  });
});
