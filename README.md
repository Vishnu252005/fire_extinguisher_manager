# Fire Extinguisher Manager

A Flutter app to manage fire extinguishers, track their expiry dates, and notify admins when they expire.

## Features

- **Admin Login**: Secure login with email and password.
- **Fire Extinguisher List**: View all extinguishers with their expiry dates and times.
- **Add Extinguisher**: Add new extinguishers with a default name and custom expiry date/time.
- **Edit Expiry**: Update the expiry date and time for any extinguisher.
- **Delete Extinguisher**: Remove extinguishers from the list with a confirmation dialog.
- **Color Coding**: Visual indicators for expired, soon-to-expire, and safe extinguishers.
- **Profile Tab**: Placeholder for admin profile features.
- **Email Notifications**: Automatic email alerts for expired or soon-to-expire extinguishers using Firebase Extensions and SMTP.

## Getting Started

### 1. Set Up Flutter
- Install Flutter by following the [official guide](https://docs.flutter.dev/get-started/install).
- Make sure you have Flutter and Dart in your PATH:
  ```bash
  flutter --version
  dart --version
  ```

### 2. Clone the Repository
```bash
git clone https://github.com/vishnu252005/fire_extinguisher_manager.git
cd fire_extinguisher_manager
```

### 3. Install Dependencies
```bash
flutter pub get
```

### 4. Run the App
```bash
flutter run
```

---

### Optional: Deploy Firebase Rules and Functions

#### Deploy Firestore Security Rules
```bash
firebase deploy --only firestore:rules
```

#### Deploy Cloud Functions
```bash
firebase deploy --only functions
```

> Make sure you have the [Firebase CLI](https://firebase.google.com/docs/cli) installed and are logged in with `firebase login`.

---

## Usage

- **Login**: Use the default admin credentials:
  - Email: `admin@example.com`
  - Password: `admin123`
- **View Extinguishers**: The main screen shows a list of extinguishers with their expiry dates and times.
- **Add Extinguisher**: Click the + icon to add a new extinguisher. The name field is pre-filled with a default name.
- **Edit Expiry**: Click the edit icon on any extinguisher to update its expiry date and time.
- **Delete Extinguisher**: Click the delete icon to remove an extinguisher (with confirmation).
- **Profile**: Navigate to the profile tab for future admin features.

## Email Notification Setup

This app uses the [Firestore Send Email Extension](https://github.com/firebase/extensions/tree/master/firestore-send-email) to send email alerts when extinguishers are expired or about to expire.

### 1. Install the Extension
- Go to the Firebase Console > Extensions.
- Search for **Trigger Email from Firestore** and install it.
- Set the collection to `mail` (default).

### 2. Configure SMTP (Gmail Example)
- In the extension settings, set the SMTP server to:
  - **Host:** `smtp.gmail.com`
  - **Port:** `465` (SSL) or `587` (TLS)
  - **Username:** Your full Gmail address (e.g., `yourname@gmail.com`)
  - **Password:** **App Password** (see below)

#### How to Get a Gmail App Password
1. Go to your [Google Account Security Settings](https://myaccount.google.com/security).
2. Enable 2-Step Verification if not already enabled.
3. Go to **App Passwords**.
4. Generate a new app password for "Mail" and "Other" (give it a name like "Firebase").
5. Use this generated password as your SMTP password in the extension config.

> **Note:** Do NOT use your regular Gmail password. App Passwords are required for security.

### 3. Document Format for Sending Emails
When the app triggers an email, it writes a document to the `mail` collection in Firestore. The document must have this format:

```json
{
  "to": ["recipient@example.com"],
  "message": {
    "subject": "Fire Extinguisher Expiry Alert",
    "text": "Dear User, Your extinguisher is expired or expiring soon."
  }
}
```
- The `to` field must be an **array** of email addresses.
- You can also use `cc`, `bcc`, `replyTo`, and `attachments` (see [extension docs](https://github.com/firebase/extensions/blob/master/firestore-send-email/POSTINSTALL.md)).

### 4. Troubleshooting
- **Error: Invalid login: 535-5.7.8 Username and Password not accepted**
  - Double-check your SMTP username and password.
  - For Gmail, make sure you are using an App Password, not your regular password.
  - See [Google App Passwords Help](https://support.google.com/accounts/answer/185833?hl=en).
- **Error: Unexpected socket close**
  - Check your SMTP server settings and network connection.
- **No email sent**
  - Make sure the document format in the `mail` collection matches the required structure.

## Future Enhancements

- Persistent storage for extinguisher data.
- Email notifications for expired extinguishers.
- More admin profile features.

## Contributing

Feel free to submit issues and pull requests.

## License

This project is licensed under the MIT License.
