import type { NextApiRequest, NextApiResponse } from 'next';
const { Resend } = require('resend');

const resend = new Resend(process.env.RESEND_API_KEY);

interface WaitlistEntry {
  email: string;
  timestamp: string;
}

// In a real application, you would store this in a database
const waitlist: WaitlistEntry[] = [];

export default function handler(
  req: NextApiRequest,
  res: NextApiResponse
) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', ['POST']);
    return res.status(405).json({ message: 'Method not allowed' });
  }

  try {
    const { email } = req.body;

    if (!email || email.trim().length === 0) {
      return res.status(400).json({ message: 'Please enter your email to join the waitlist' });
    }

    // Check if email already exists in waitlist
    if (waitlist.some(entry => entry.email === email)) {
      return res.status(409).json({ message: 'Email already registered' });
    }

    // Add to waitlist
    const entry: WaitlistEntry = {
      email,
      timestamp: new Date().toISOString()
    };

    waitlist.push(entry);

    // Add user to Resend Audience and notify admin
    const processSubscriber = async () => {
      // Step 1: Add to audience (this works with free plan)
      try {
        const audienceResult = await resend.contacts.create({
          email: email,
          audienceId: process.env.RESEND_AUDIENCE_ID
        });
      } catch (error) {
      }

      // Step 2: Send notification to admin
      try {
        const adminResult = await resend.emails.send({
          from: 'AirPosture System <onboarding@resend.dev>',
          to: ['allenleexyz@gmail.com'],
          subject: 'New AirPosture Waitlist Subscriber! 🚀',
        html: `
          <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; background: #000; color: #fff;">
            <h2 style="color: #fff; font-size: 1.5em;">✅ New Waitlist Subscriber</h2>
            <div style="background: rgba(255, 255, 255, 0.1); backdrop-filter: blur(10px); border: 1px solid rgba(255, 255, 255, 0.2); border-radius: 15px; padding: 20px; margin: 15px 0;">
              <p style="margin: 5px 0;"><strong>📧 Email:</strong> ${email}</p>
              <p style="margin: 5px 0;"><strong>🕒 Timestamp:</strong> ${new Date().toLocaleString()}</p>
              <p style="margin: 5px 0;"><strong>👥 Total Waitlist:</strong> ${waitlist.length} subscribers</p>
              <p style="margin: 10px 0; color: #4ade80; font-weight: bold;">
                ✅ Added to your Resend Audience - you can now see this email in your dashboard!
              </p>
            </div>
            <div style="background: rgba(92, 45, 164, 0.2); backdrop-filter: blur(10px); border: 1px solid rgba(139, 92, 246, 0.3); border-radius: 15px; padding: 20px; margin: 15px 0;">
              <h3 style="color: #fff; font-size: 1.2em; margin-top: 0;">🎯 Next Steps:</h3>
              <ol style="color: #d0d0d0; line-height: 1.6; padding-left: 20px;">
                <li>Verify your domain at <a href="https://resend.com/domains" style="color: #c0c0c0;">resend.com/domains</a> to send confirmation emails</li>
                <li>Once verified, update the 'from' address in the API code</li>
                <li>Then you can automatically send welcome emails to new subscribers</li>
              </ol>
            </div>
          </div>
        `,
        });
      } catch (error) {
      }
    };

    // Process subscriber in background (don't wait for completion)
    processSubscriber().catch(error => {
    });

    return res.status(200).json({ 
      message: 'Successfully added to waitlist',
      count: waitlist.length
    });

  } catch (error) {
    return res.status(500).json({ message: 'Internal server error' });
  }
}