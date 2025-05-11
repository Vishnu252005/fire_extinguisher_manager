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

## Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/fire_extinguisher_manager.git
   cd fire_extinguisher_manager
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

## Usage

- **Login**: Use the default admin credentials:
  - Email: `admin@example.com`
  - Password: `admin123`
- **View Extinguishers**: The main screen shows a list of extinguishers with their expiry dates and times.
- **Add Extinguisher**: Click the + icon to add a new extinguisher. The name field is pre-filled with a default name.
- **Edit Expiry**: Click the edit icon on any extinguisher to update its expiry date and time.
- **Delete Extinguisher**: Click the delete icon to remove an extinguisher (with confirmation).
- **Profile**: Navigate to the profile tab for future admin features.

## Future Enhancements

- Persistent storage for extinguisher data.
- Email notifications for expired extinguishers.
- More admin profile features.

## Contributing

Feel free to submit issues and pull requests.

## License

This project is licensed under the MIT License.
