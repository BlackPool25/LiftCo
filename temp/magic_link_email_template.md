# LiftCo Magic Link Email Template

## Subject Line
```
🏋️ Your LiftCo Login Link
```

---

## Email Template (HTML)

Copy this into Supabase → Authentication → Email Templates → Magic Link

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; background-color: #0A0A0F; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #0A0A0F; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="100%" style="max-width: 480px; background: linear-gradient(135deg, #15151A 0%, #1A1A24 100%); border-radius: 24px; border: 1px solid #2A2A35; overflow: hidden;">
          
          <!-- Header with Logo -->
          <tr>
            <td style="padding: 40px 40px 24px 40px; text-align: center;">
              <div style="display: inline-block; padding: 16px; background: linear-gradient(135deg, #E8956A 0%, #F0A878 100%); border-radius: 16px;">
                <span style="font-size: 24px;">🏋️</span>
              </div>
              <h1 style="color: #F8FAFC; font-size: 28px; font-weight: 700; margin: 24px 0 0 0; letter-spacing: -0.5px;">
                LiftCo
              </h1>
            </td>
          </tr>
          
          <!-- Main Content -->
          <tr>
            <td style="padding: 0 40px 32px 40px; text-align: center;">
              <h2 style="color: #F8FAFC; font-size: 22px; font-weight: 600; margin: 0 0 12px 0;">
                Sign in to your account
              </h2>
              <p style="color: #94A3B8; font-size: 15px; line-height: 1.6; margin: 0;">
                Click the button below to securely sign in. This link expires in 24 hours.
              </p>
            </td>
          </tr>
          
          <!-- CTA Button -->
          <tr>
            <td style="padding: 0 40px 32px 40px; text-align: center;">
              <a href="{{ .ConfirmationURL }}" 
                 style="display: inline-block; padding: 16px 40px; background: linear-gradient(135deg, #E8956A 0%, #F0A878 100%); color: #FFFFFF; text-decoration: none; font-size: 16px; font-weight: 600; border-radius: 14px; box-shadow: 0 8px 24px rgba(232, 149, 106, 0.3);">
                Sign In to LiftCo
              </a>
            </td>
          </tr>
          
          <!-- Security Note -->
          <tr>
            <td style="padding: 0 40px 40px 40px;">
              <div style="background-color: #1E1E28; border-radius: 12px; padding: 16px; border-left: 3px solid #4ECDC4;">
                <p style="color: #94A3B8; font-size: 13px; margin: 0; line-height: 1.5;">
                  <strong style="color: #4ECDC4;">🔒 Security tip:</strong> If you didn't request this email, you can safely ignore it.
                </p>
              </div>
            </td>
          </tr>
          
          <!-- Footer -->
          <tr>
            <td style="padding: 24px 40px; background-color: #12121A; text-align: center; border-top: 1px solid #2A2A35;">
              <p style="color: #64748B; font-size: 12px; margin: 0;">
                © 2024 LiftCo. Find your perfect gym buddy.
              </p>
            </td>
          </tr>
          
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
```

---

## How to Add in Supabase

1. Go to **Supabase Dashboard** → **Authentication** → **Email Templates**
2. Select **Magic Link** from the dropdown
3. Set **Subject**: `🏋️ Your LiftCo Login Link`
4. Paste the HTML template above
5. Click **Save**

---

## Template Variables

| Variable | Description |
|----------|-------------|
| `{{ .ConfirmationURL }}` | The magic link URL (required) |
| `{{ .Email }}` | User's email address |
| `{{ .SiteURL }}` | Your app's site URL |
