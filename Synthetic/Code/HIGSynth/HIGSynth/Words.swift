import Foundation

/// Vocabulary the generator draws from. Add more entries to increase variety.
enum Words {
    static let screenTitles = [
        "Settings", "Profile", "Account", "Notifications", "Privacy", "Discover", "Library", "Inbox",
        "Orders", "Activity", "Explore", "Favorites", "Messages", "Home", "Wallet", "Workouts",
        "Recipes", "Trips", "Projects", "Reminders", "Downloads", "Playlists", "Contacts", "Bookings",
    ]

    static let tabs: [(title: String, symbol: String)] = [
        ("Home", "house"), ("Search", "magnifyingglass"), ("Library", "books.vertical"),
        ("Profile", "person.crop.circle"), ("Settings", "gear"), ("Favorites", "heart"),
        ("Browse", "square.grid.2x2"), ("Inbox", "tray"), ("Activity", "chart.bar"),
        ("Cart", "cart"), ("Explore", "safari"), ("Messages", "message"),
        ("Music", "music.note"), ("Map", "map"), ("Wallet", "creditcard"),
    ]

    static let settingTitles = [
        "Notifications", "Dark Mode", "Location Services", "Face ID", "Auto-Lock", "Sounds", "Haptics",
        "Wi-Fi", "Bluetooth", "Airplane Mode", "Background Refresh", "Cellular Data", "Low Power Mode",
        "Show Previews", "Sync Contacts", "iCloud Backup", "Share Analytics", "Personalized Ads",
        "Email Updates", "Weekly Summary", "Auto-Play Videos", "Download over Wi-Fi", "Show Badges",
        "Do Not Disturb", "Language", "Text Size", "Storage", "Subscriptions", "Payment Methods",
        "Help & Support", "About",
    ]

    static let details = [
        "On", "Off", "English", "Never", "5 min", "Default", "Large", "12.4 GB", "Always",
        "Weekly", "Automatic", "2 devices", "Free", "Premium",
    ]

    static let sectionHeaders = [
        "General", "Account", "Notifications", "Privacy & Security", "Appearance", "Connectivity",
        "Data", "Support", "Preferences", "Recently Added", "Favorites", "Today", "This Week", "Suggestions",
    ]

    static let itemTitles = [
        "Morning Run", "Team Standup", "Grocery List", "Flight to Rome", "Weekend Playlist",
        "Pasta Carbonara", "Invoice #2041", "Mom", "Design Review", "Coffee Order", "Book Club",
        "Yoga Class", "Electric Bill", "Photo Album", "Project Atlas", "Dentist Appointment",
        "Bike Repair", "Concert Tickets", "Study Notes", "Garden Plan",
    ]

    static let trailings = [
        "9:41 AM", "Yesterday", "Mon", "$12.99", "3 min", "2.4 km", "New", "4.8", "12", "Oct 8",
    ]

    static let sentences = [
        "Get notified when something important happens.",
        "Your changes are saved automatically.",
        "Choose how you want to receive updates.",
        "Track your progress and reach your goals faster.",
        "Shared with 3 people",
        "Last updated 2 hours ago",
        "Arrives tomorrow by 6 PM",
        "Tap to see more details.",
        "We'll never share your email with anyone else.",
        "Includes 7-day free trial, cancel anytime.",
        "Synced across all your devices.",
        "Battery usage may increase when this is on.",
        "Remember to bring your ticket.",
        "New messages from the design team.",
        "3 items, $42.50",
        "Recommended based on your recent activity.",
        "You can change this later in Settings.",
        "Ready to pick up at the front desk.",
    ]

    static let headings = [
        "Welcome back", "Your Activity", "Get Started", "Today's Picks", "Account Details",
        "Choose a Plan", "Recent Orders", "Your Goals", "Almost there", "Trending Now",
        "Order Summary", "Personalize Your Feed",
    ]

    static let authHeadings = [
        "Welcome back", "Sign in", "Create account", "Join today", "Log in to continue", "Let's get started",
    ]

    static let authPrimary = ["Sign In", "Log In", "Continue", "Create Account", "Get Started", "Next"]

    static let authSecondary = [
        "Forgot password?", "Create an account", "Sign in later", "Need help?", "Use a different method",
    ]

    static let altSignIn: [(title: String, symbol: String)] = [
        ("Email", "envelope"), ("Phone", "phone"), ("Passkey", "key"), ("SSO", "building.2"),
    ]

    static let buttonTitles = [
        "Continue", "Save", "Get Started", "Add to Cart", "Share", "Learn More", "Delete", "Cancel",
        "Done", "Next", "Subscribe", "Try Again", "Book Now", "Upgrade", "Follow", "Send",
        "Edit Profile", "View All", "Apply", "Download", "Start Workout", "Checkout",
        "Invite Friends", "Confirm", "Skip",
    ]

    static let placeholders = [
        "Email", "Full Name", "Phone Number", "Address", "Promo code", "City", "Message",
        "Username", "Website", "Card number", "Add a note", "Title", "Amount",
    ]

    static let prefills = [
        "Asad", "alex@example.com", "Rome", "Hello there!", "+39 333 123 4567", "Via Roma 12",
    ]

    static let segmentSets: [[String]] = [
        ["Day", "Week", "Month"], ["All", "Unread"], ["Light", "Dark", "Auto"], ["List", "Grid"],
        ["Popular", "New", "Top"], ["Monthly", "Yearly"], ["Map", "Satellite"],
        ["Recent", "Saved", "Shared"], ["S", "M", "L", "XL"],
    ]

    static let searchPrompts = [
        "Search", "Search settings", "Search messages", "Find recipes", "Search songs, artists", "Search orders",
    ]

    static let symbols = [
        "bell", "lock", "wifi", "person.crop.circle", "gear", "star", "heart", "cart", "envelope",
        "map", "camera", "photo", "music.note", "bookmark", "calendar", "clock", "house",
        "square.and.arrow.up", "trash", "plus", "airplane", "globe", "creditcard", "bolt", "leaf",
        "flame", "moon", "sun.max", "paperplane", "folder", "doc.text", "chart.bar", "gamecontroller",
        "headphones", "tv", "car", "bicycle", "cup.and.saucer", "fork.knife", "bag", "gift",
    ]
}
