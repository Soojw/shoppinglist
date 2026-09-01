import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_model.dart';
import '../models/price_model.dart';
import '../services/database_service.dart';
import '../services/user_login_page.dart';
import '../services/user_provider.dart';

class ProductPage extends StatefulWidget {
  final PriceDropItem item;
  final bool isAdminView;
  final bool isLocalItem;

  const ProductPage({
    super.key,
    required this.item,
    this.isAdminView = false,
    this.isLocalItem = false,
  });

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  bool _isFavorited = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.isAdminView) {
      _isLoading = false;
    } else {
      _checkFavoriteStatus();
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.isLoggedIn) {
      final favoriteIds = await DatabaseService().getUserFavoriteIds(userProvider.userEmail);
      if (favoriteIds.contains(widget.item.itemCode) || favoriteIds.contains(widget.item.title)) {
        _isFavorited = true;
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _handleFavoriteTap() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (!userProvider.isLoggedIn) {
      _showLoginPrompt();
      return;
    }

    setState(() {
      _isFavorited = !_isFavorited;
    });

    await DatabaseService().toggleFavorite(userProvider.userEmail, widget.item.itemCode, widget.item.title);

    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isFavorited ? 'Added to your alerts!' : 'Removed from alerts.'), duration: const Duration(seconds: 1), backgroundColor: const Color(0xFF059669)));
    }
  }

  void _showLoginPrompt() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Sign In Required', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Log in to save items and get targeted price drop alerts.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const UserLoginPage()));
                  if (result == true) {
                    _checkFavoriteStatus();
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('Go to Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogCtx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete ${widget.item.title.isNotEmpty ? widget.item.title : widget.item.itemCode}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              await DatabaseService().deleteProductFromCatalog(widget.item.itemCode);
              if (context.mounted) {
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product Deleted'), backgroundColor: Colors.redAccent));
                Navigator.of(context).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    final TextEditingController nameController = TextEditingController(text: widget.item.title);
    final TextEditingController barcodeController = TextEditingController(text: widget.item.barcode);
    final TextEditingController priceController = TextEditingController(text: widget.item.newPrice.replaceAll('RM ', ''));
    final TextEditingController imageController = TextEditingController(text: widget.item.imageUrl);
    final TextEditingController detailsController = TextEditingController(text: widget.item.details);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit: ${widget.item.itemCode}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: InputDecoration(labelText: 'Item Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(controller: barcodeController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Barcode', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(controller: priceController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Official Price', prefixText: 'RM ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(controller: imageController, decoration: InputDecoration(labelText: 'Image URL', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(controller: detailsController, maxLines: 2, decoration: InputDecoration(labelText: 'Details', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || priceController.text.trim().isEmpty) return;
              await DatabaseService().updateProductInCatalog(
                widget.item.itemCode,
                barcodeController.text.trim().isEmpty ? 'N/A' : barcodeController.text.trim(),
                nameController.text.trim(),
                priceController.text.trim(),
                imageController.text.trim(),
                detailsController.text.trim(),
              );
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product Updated'), backgroundColor: Color(0xFF059669)));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomBar() {
    if (!widget.isAdminView) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -10))]),
        child: SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: () async {
              final newItem = CartItemModel(itemName: widget.item.title, price: widget.item.newPrice, storeName: widget.item.storePrices.isNotEmpty ? widget.item.storePrices.first.storeName : widget.item.store, quantity: 1);
              await DatabaseService().insertItem(newItem);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.item.title} added to list!'), backgroundColor: const Color(0xFF059669), duration: const Duration(seconds: 1)));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: const Text('Add to List', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
        child: widget.isLocalItem
            ? Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _confirmDelete, icon: const Icon(Icons.delete_outline, color: Colors.redAccent), label: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showEditDialog, icon: const Icon(Icons.edit, color: Colors.white), label: const Text('Edit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: const Color(0xFF059669), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
        )
            : SizedBox(
          width: double.infinity, height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
              const SizedBox(width: 8),
              Text('OFFICIAL LIVE FEED - READ ONLY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2)),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color deepSlate = Color(0xFF1E293B);
    const Color primaryGreen = Color(0xFF059669);

    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: deepSlate), onPressed: () => Navigator.pop(context)),
        actions: [
          if (!widget.isAdminView) ...[
            IconButton(icon: Icon(_isFavorited ? Icons.favorite : Icons.favorite_border, color: _isFavorited ? Colors.redAccent : deepSlate), onPressed: _handleFavoriteTap),
            IconButton(icon: const Icon(Icons.share, color: deepSlate), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sharing coming soon!')))),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24), height: 250,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))], image: DecorationImage(image: NetworkImage(widget.item.imageUrl), fit: BoxFit.cover)),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: deepSlate, borderRadius: BorderRadius.circular(8)), child: Text(widget.item.category.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8)), child: Text('SKU: ${widget.item.itemCode}', style: const TextStyle(color: deepSlate, fontSize: 10, fontWeight: FontWeight.bold))),
                      if (widget.item.barcode != 'N/A' && widget.item.barcode.isNotEmpty)
                        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.qr_code_2, size: 12, color: Color(0xFF92400E)), const SizedBox(width: 4), Text(widget.item.barcode, style: const TextStyle(color: Color(0xFF92400E), fontSize: 10, fontWeight: FontWeight.bold))])),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(widget.item.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: deepSlate, height: 1.2)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFA7F3D0))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.verified_user, color: primaryGreen, size: 24), const SizedBox(width: 12), Expanded(child: Text(widget.item.details, style: const TextStyle(color: Color(0xFF065F46), fontSize: 13, height: 1.5, fontWeight: FontWeight.w500)))]),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(widget.item.newPrice, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: primaryGreen)),
                      if (widget.item.oldPrice.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(widget.item.oldPrice, style: const TextStyle(fontSize: 18, color: Colors.grey, decoration: TextDecoration.lineThrough, fontWeight: FontWeight.bold))),
                      ],
                      const Spacer(),
                      const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('NATIONWIDE', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.0))),
                    ],
                  ),
                  const SizedBox(height: 40),

                  if (widget.item.storePrices.isNotEmpty) ...[
                    const Text('Prices at Different Stores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: deepSlate)),
                    const SizedBox(height: 16),
                    ...widget.item.storePrices.map((sp) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sp.storeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: deepSlate)),
                                  const SizedBox(height: 4),
                                  Row(children: [const Icon(Icons.location_on, size: 12, color: Colors.grey), const SizedBox(width: 4), Expanded(child: Text(sp.state, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis))]),
                                ],
                              ),
                            ),
                            Text(sp.price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryGreen)),
                          ],
                        ),
                      );
                    }),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomBar(),
    );
  }
}