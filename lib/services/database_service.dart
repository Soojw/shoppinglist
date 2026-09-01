import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/cart_model.dart';

class DatabaseService {
  static final DatabaseService _databaseService = DatabaseService._internal();
  factory DatabaseService() => _databaseService;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    final getDirectory = await getApplicationDocumentsDirectory();
    String path = '${getDirectory.path}/smart_shopping.db';
    return await openDatabase(path, onCreate: _onCreate, version: 4);
  }

  void _onCreate(Database db, int version) async {
    await db.execute(
        'CREATE TABLE Cart('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'itemName TEXT, '
            'price TEXT, '
            'storeName TEXT, '
            'quantity INTEGER)'
    );

    await db.execute('''
        CREATE TABLE Catalog(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          item_code TEXT,
          barcode TEXT,       
          category TEXT,
          item_name TEXT,
          old_price TEXT,
          price TEXT,
          image_url TEXT,
          details TEXT
        )
      ''');

    await db.execute(
        'CREATE TABLE Users('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'name TEXT, '
            'email TEXT, '
            'password TEXT, '
            'status TEXT, '
            'wants_price_drop INTEGER DEFAULT 1, '
            'wants_order_updates INTEGER DEFAULT 1, '
            'wants_new_arrivals INTEGER DEFAULT 0, '
            'wants_promotions INTEGER DEFAULT 1, '
            'wants_newsletter INTEGER DEFAULT 0)'
    );

    await db.execute(
        'CREATE TABLE Favorites('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'user_email TEXT, '
            'product_id TEXT, '
            'product_name TEXT)'
    );

    await db.execute(
        'CREATE TABLE Notifications('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'user_email TEXT, '
            'title TEXT, '
            'message TEXT, '
            'is_read INTEGER DEFAULT 0, '
            'timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)'
    );
  }


  Future<void> insertItem(CartItemModel item) async {
    final db = await _databaseService.database;
    await db.insert('Cart', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CartItemModel>> getCartItems() async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query('Cart');
    return List.generate(maps.length, (i) {
      return CartItemModel(
        id: maps[i]['id'],
        itemName: maps[i]['itemName'],
        price: maps[i]['price'],
        storeName: maps[i]['storeName'],
        quantity: maps[i]['quantity'] ?? 1,
      );
    });
  }

  Future<void> updateItemQuantity(int? id, int newQuantity) async {
    if (id == null) return;
    final db = await _databaseService.database;
    if (newQuantity <= 0) {
      await db.delete('Cart', where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update('Cart', {'quantity': newQuantity}, where: 'id = ?', whereArgs: [id]);
    }
  }


  Future<void> addProductToCatalog(
      String itemCode,
      String barcode,
      String category,
      String itemName,
      String oldPrice,
      String price,
      String imageUrl,
      String details
      ) async {
    final db = await database;
    await db.insert(
      'Catalog',
      {
        'item_code': itemCode,
        'barcode': barcode,
        'category': category,
        'item_name': itemName,
        'old_price': oldPrice,
        'price': price,
        'image_url': imageUrl,
        'details': details,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getFullCatalog() async {
    final db = await _databaseService.database;
    return await db.query('Catalog', orderBy: 'id DESC');
  }


  Future<void> registerUser(String name, String email, String password) async {
    final db = await _databaseService.database;
    await db.insert('Users', {
      'name': name,
      'email': email,
      'password': password,
      'status': 'Active',
    });
  }


  Future<Map<String, dynamic>?> loginUser(String identifier, String password) async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> results = await db.query(
      'Users',
      where: '(email = ? OR name = ?) AND password = ?',
      whereArgs: [identifier, identifier, password],
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await _databaseService.database;
    return await db.query('Users', orderBy: 'id DESC');
  }

  Future<void> updatePassword(String email, String newPassword) async {
    final db = await _databaseService.database;
    await db.update(
      'Users',
      {'password': newPassword},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  Future<void> updateNotificationPreference(String email, String columnName, int value) async {
    final db = await _databaseService.database;
    await db.update(
      'Users',
      {columnName: value},
      where: 'email = ?',
      whereArgs: [email],
    );
  }


  Future<void> toggleFavorite(String email, String productId, String productName) async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> existing = await db.query(
      'Favorites',
      where: 'user_email = ? AND product_id = ?',
      whereArgs: [email, productId],
    );

    if (existing.isNotEmpty) {
      await db.delete('Favorites', where: 'user_email = ? AND product_id = ?', whereArgs: [email, productId]);
    } else {
      await db.insert('Favorites', {'user_email': email, 'product_id': productId, 'product_name': productName});
    }
  }

  Future<List<String>> getUserFavoriteIds(String email) async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'Favorites',
      columns: ['product_id'],
      where: 'user_email = ?',
      whereArgs: [email],
    );
    return List.generate(maps.length, (i) => maps[i]['product_id'] as String);
  }

  Future<List<Map<String, dynamic>>> getTopFavoritedItems() async {
    final db = await _databaseService.database;
    return await db.rawQuery(
        'SELECT product_name, COUNT(product_id) as count '
            'FROM Favorites '
            'GROUP BY product_id '
            'ORDER BY count DESC '
            'LIMIT 5'
    );
  }


  Future<void> sendNotification(String email, String title, String message) async {
    final db = await _databaseService.database;
    await db.insert('Notifications', {
      'user_email': email,
      'title': title,
      'message': message,
      'is_read': 0,
    });
  }

  Future<int> getUnreadNotificationCount(String email) async {
    final db = await _databaseService.database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) FROM Notifications WHERE user_email = ? AND is_read = 0',
        [email]
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getUserNotifications(String email) async {
    final db = await _databaseService.database;
    return await db.query(
      'Notifications',
      where: 'user_email = ?',
      whereArgs: [email],
      orderBy: 'id DESC',
    );
  }

  Future<void> markNotificationAsRead(int id) async {
    final db = await _databaseService.database;
    await db.update(
      'Notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteProductFromCatalog(String itemCode) async {
    final db = await database;
    await db.delete(
      'Catalog',
      where: 'item_code = ?',
      whereArgs: [itemCode],
    );
  }

  Future<void> updateProductInCatalog(String itemCode, String barcode, String itemName, String price, String imageUrl, String details) async {
    final db = await database;
    await db.update(
      'Catalog',
      {
        'barcode': barcode,
        'item_name': itemName,
        'price': price,
        'image_url': imageUrl,
        'details': details,
      },
      where: 'item_code = ?',
      whereArgs: [itemCode],
    );
  }



  Future<void> sendBroadcastNotification(String title, String message) async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> users = await db.query('Users');

    Batch batch = db.batch();


    bool isPromoMessage = title.contains('Promo');

    for (var user in users) {
      if (isPromoMessage && user['wants_promotions'] == 0) {
        continue;
      }


      batch.insert('Notifications', {
        'user_email': user['email'],
        'title': title,
        'message': message,
        'is_read': 0,
      });
    }

    await batch.commit(noResult: true);
  }


  Future<List<Map<String, dynamic>>> getBroadcastHistory() async {
    final db = await _databaseService.database;
    return await db.rawQuery(
        'SELECT DISTINCT title, message, timestamp '
            'FROM Notifications '
            'ORDER BY timestamp DESC'
    );
  }




  Future<void> _ensureTicketsTableExists(Database db) async {
    await db.execute(
        'CREATE TABLE IF NOT EXISTS Tickets('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'user_email TEXT, '
            'category TEXT, '
            'description TEXT, '
            'status TEXT DEFAULT "Open", '
            'timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)'
    );
  }


  Future<void> submitTicket(String email, String category, String description) async {
    final db = await _databaseService.database;
    await _ensureTicketsTableExists(db);

    await db.insert('Tickets', {
      'user_email': email.isEmpty ? 'guest@smartshopping.com' : email,
      'category': category,
      'description': description,
      'status': 'Open',
    });
  }


  Future<List<Map<String, dynamic>>> getAllTickets() async {
    final db = await _databaseService.database;
    await _ensureTicketsTableExists(db);

    return await db.query('Tickets', orderBy: 'id DESC');
  }


  Future<void> resolveTicket(int id) async {
    final db = await _databaseService.database;
    await _ensureTicketsTableExists(db);

    await db.update('Tickets', {'status': 'Resolved'}, where: 'id = ?', whereArgs: [id]);
  }
}