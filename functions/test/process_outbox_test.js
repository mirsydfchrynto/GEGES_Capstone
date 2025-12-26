const { expect } = require('chai');
const sg = require('../sendgrid_helper');
const mod = require('../index');

describe('processOutboxEmail handler', () => {
  it('should mark outbox doc skipped when SENDGRID_API_KEY not set', async () => {
    // ensure helper returns skipped
    const original = sg.sendEmailViaSendGrid;
    sg.sendEmailViaSendGrid = async () => ({ status: 'skipped', info: 'no key' });

    const updates = [];
    const snap = {
      data: () => ({ to: 'owner@example.com', subject: 'Approval', body: 'You were approved' }),
      ref: {
        update: async (obj) => { updates.push(obj); }
      }
    };
    const context = { params: { docId: 'abc123' } };

    await mod._processOutboxEmailHandler(snap, context);

    // first update should mark processing, final update should be skipped
    expect(updates.length).to.be.at.least(2);
    const final = updates[updates.length - 1];
    expect(final).to.have.property('status', 'skipped');
    expect(final).to.have.property('reason');

    // restore
    sg.sendEmailViaSendGrid = original;
  });
});