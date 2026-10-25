/// A single password-vault entry. Stored ONLY in the AES-encrypted
/// Hive box (see VaultService) — never in plain Hive, files or notes.
class VaultEntry {
  String id;
  String title;
  String username;
  String password;
  String website;
  String category; // Social | Bank | Email | Work | Other
  String notes;
  bool favourite;
  int createdAtMs;
  int updatedAtMs;

  VaultEntry({
    required this.id,
    required this.title,
    this.username = '',
    required this.password,
    this.website = '',
    this.category = 'Other',
    this.notes = '',
    this.favourite = false,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'username': username,
        'password': password,
        'website': website,
        'category': category,
        'notes': notes,
        'favourite': favourite,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
      };

  factory VaultEntry.fromMap(Map<String, dynamic> m) => VaultEntry(
        id: m['id'] as String,
        title: m['title'] as String? ?? '',
        username: m['username'] as String? ?? '',
        password: m['password'] as String? ?? '',
        website: m['website'] as String? ?? '',
        category: m['category'] as String? ?? 'Other',
        notes: m['notes'] as String? ?? '',
        favourite: m['favourite'] as bool? ?? false,
        createdAtMs: (m['createdAtMs'] as num?)?.toInt() ?? 0,
        updatedAtMs: (m['updatedAtMs'] as num?)?.toInt() ?? 0,
      );
}

const vaultCategories = ['Social', 'Bank', 'Email', 'Work', 'Other'];
