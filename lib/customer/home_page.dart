import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/login_page.dart';
import 'cart_page.dart';
import 'order_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  int currentIndex = 0;
  List barangList = [];
  bool isLoading = true;
  bool _cartIconBouncing = false;
  int cartCount = 0;

  // GlobalKey untuk CartPageState dan OrdersPageState
  final GlobalKey<CartPageState> _cartKey = GlobalKey<CartPageState>();
  final GlobalKey<OrdersPageState> _ordersKey = GlobalKey<OrdersPageState>();

  bool get isLogin => supabase.auth.currentUser != null;

  Future<void> getBarang() async {
    try {
      final data = await supabase
          .from('tabel_barang')
          .select()
          .eq('status', 'tersedia');
      setState(() {
        barangList = data;
        isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() => isLoading = false);
    }
  }

  Future<void> addToCart(int idBarang) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
        return;
      }
      await supabase.from('tabel_keranjang').insert({
        'auth_id': user.id,
        'id_barang': idBarang,
        'qty': 1,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berhasil masuk keranjang'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await getCartCount();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> getCartCount() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => cartCount = 0);
      return;
    }
    try {
      final response = await supabase
          .from('tabel_keranjang')
          .select('qty')
          .eq('auth_id', user.id);
      
      int totalQty = 0;
      for (var item in response) {
        totalQty += (item['qty'] as int);
      }
      
      if (mounted) {
        setState(() {
          cartCount = totalQty;
        });
      }
    } catch (e) {
      print('Error getting cart count: $e');
    }
  }

  void _triggerCartIconBounce() {
    setState(() {
      _cartIconBouncing = true;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _cartIconBouncing = false;
        });
      }
    });
  }

  void runFlyToCartAnimation(BuildContext btnContext) {
    final RenderBox? renderBox = btnContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final Offset buttonPosition = renderBox.localToGlobal(Offset.zero);
    final Size buttonSize = renderBox.size;

    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    // Posisi perkiraan icon keranjang pada bottom navigation bar
    final Offset targetPosition = Offset(
      screenWidth * 0.375, // Sekitar 37.5% lebar layar untuk tab ke-2
      screenHeight - 50,
    );

    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) {
        return FlyToCartWidget(
          startPosition: buttonPosition + Offset(buttonSize.width / 2, buttonSize.height / 2),
          endPosition: targetPosition,
          onComplete: () {
            overlayEntry.remove();
            _triggerCartIconBounce();
          },
        );
      },
    );

    Overlay.of(context).insert(overlayEntry);
  }

  @override
  void initState() {
    super.initState();
    getBarang();
    getCartCount();
  }

  Widget tokoPage() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFFF8C42)),
            SizedBox(height: 16),
            Text('Memuat produk...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    if (barangList.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          setState(() => isLoading = true);
          await getBarang();
        },
        color: const Color(0xFFFF8C42),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.store_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada produk tersedia',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tarik ke bawah untuk memuat ulang',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => isLoading = true);
        await getBarang();
      },
      color: const Color(0xFFFF8C42),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: barangList.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.65,
        ),
        itemBuilder: (context, index) {
          final barang = barangList[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.grey.shade100,
                width: 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.network(
                    barang['foto'],
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 110,
                      color: Colors.grey.shade100,
                      child: const Icon(
                        Icons.broken_image,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          barang['nama_barang'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rp ${barang['harga'].toInt()}',
                          style: const TextStyle(
                            color: Color(0xFFFF8C42),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 12,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Stok: ${barang['stok']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: Builder(
                            builder: (btnContext) {
                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isLogin
                                      ? ((barang['stok'] ?? 0) <= 0
                                          ? Colors.grey.shade400
                                          : const Color(0xFFFF8C42))
                                      : Colors.grey.shade400,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  if (!isLogin) {
                                    final shouldLogin = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        title: const Text('Belum Login'),
                                        content: const Text(
                                          'Silakan login terlebih dahulu.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Batal'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFFF8C42,
                                              ),
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Login'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (shouldLogin == true) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const LoginPage(),
                                        ),
                                      );
                                    }
                                    return;
                                  }

                                  // Cek jika stok habis
                                  if ((barang['stok'] ?? 0) <= 0) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        title: const Text('Barang Habis'),
                                        content: const Text(
                                          'Mohon maaf, stok produk ini sudah habis dan tidak dapat dipesan.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                    return;
                                  }

                                  await addToCart(barang['id_barang']);
                                  runFlyToCartAnimation(btnContext);
                                },
                                child: Text(
                                  isLogin
                                      ? ((barang['stok'] ?? 0) <= 0
                                          ? 'Habis'
                                          : 'Masukkan Keranjang')
                                      : 'Login',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      tokoPage(),
      isLogin
          ? CartPage(key: _cartKey, onCartUpdated: getCartCount)
          : const Center(child: LoginPage()),
      isLogin
          ? OrdersPage(key: _ordersKey)
          : const Center(child: LoginPage()), // key ditambahkan
      isLogin ? const ProfilePage() : const Center(child: LoginPage()),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFEF7E8),
      appBar: AppBar(
        title: const Text(
          'PreOrder Ayam',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        backgroundColor: const Color(0xFFFF8C42),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (!isLogin)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  ).then((_) {
                    setState(() {});
                    getCartCount();
                  });
                },
                icon: const Icon(Icons.login, color: Colors.white, size: 20),
                label: const Text(
                  'Login',
                  style: TextStyle(color: Colors.white),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            )
          else
            PopupMenuButton(
              icon: const Icon(Icons.account_circle, color: Colors.white),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Color(0xFFFF8C42), size: 20),
                      SizedBox(width: 12),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'logout') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: const Text('Konfirmasi Logout'),
                      content: const Text('Apakah Anda yakin ingin keluar?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8C42),
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await supabase.auth.signOut();
                    setState(() {
                      cartCount = 0;
                    });
                  }
                }
              },
            ),
        ],
      ),
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFFF8C42),
          unselectedItemColor: Colors.grey.shade500,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          elevation: 0,
          onTap: (index) {
            setState(() {
              currentIndex = index;
            });
            // Refresh cart saat tab keranjang dipilih
            if (index == 1 && isLogin) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _cartKey.currentState?.refreshCart();
              });
            }
            // Refresh orders saat tab pesanan dipilih
            if (index == 2 && isLogin) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _ordersKey.currentState?.refreshOrders();
              });
            }
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.store_outlined),
              activeIcon: Icon(Icons.store),
              label: 'Toko',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                label: Text('$cartCount'),
                isLabelVisible: cartCount > 0,
                child: BouncingCartIcon(
                  isBouncing: _cartIconBouncing,
                  isActive: false,
                ),
              ),
              activeIcon: Badge(
                label: Text('$cartCount'),
                isLabelVisible: cartCount > 0,
                child: BouncingCartIcon(
                  isBouncing: _cartIconBouncing,
                  isActive: true,
                ),
              ),
              label: 'Keranjang',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Pesanan',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ================= WIDGET ANIMASI TERBANG KE KERANJANG =================
class FlyToCartWidget extends StatefulWidget {
  final Offset startPosition;
  final Offset endPosition;
  final VoidCallback onComplete;

  const FlyToCartWidget({
    super.key,
    required this.startPosition,
    required this.endPosition,
    required this.onComplete,
  });

  @override
  State<FlyToCartWidget> createState() => _FlyToCartWidgetState();
}

class _FlyToCartWidgetState extends State<FlyToCartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuad,
    );

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final double t = _progress.value;
        
        // Pergerakan parabola (arc)
        final double x = widget.startPosition.dx + (widget.endPosition.dx - widget.startPosition.dx) * t;
        final double y = widget.startPosition.dy + (widget.endPosition.dy - widget.startPosition.dy) * t - (120 * (1 - t) * t);

        final double scale = 1.0 - (0.8 * t);
        final double opacity = 1.0 - (0.4 * t);

        return Positioned(
          left: x - 18,
          top: y - 18,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF8C42),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ================= WIDGET ICON KERANJANG MEMBAL =================
class BouncingCartIcon extends StatefulWidget {
  final bool isBouncing;
  final bool isActive;

  const BouncingCartIcon({
    super.key,
    required this.isBouncing,
    required this.isActive,
  });

  @override
  State<BouncingCartIcon> createState() => _BouncingCartIconState();
}

class _BouncingCartIconState extends State<BouncingCartIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.8), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.0), weight: 30),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant BouncingCartIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBouncing && !oldWidget.isBouncing) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Icon(
        widget.isActive ? Icons.shopping_cart : Icons.shopping_cart_outlined,
      ),
    );
  }
}
