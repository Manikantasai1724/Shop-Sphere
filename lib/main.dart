// ignore_for_file: unnecessary_underscores, curly_braces_in_flow_control_structures

import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _accent = Color(0xffe86a33);
const _baseUrl = 'https://dummyjson.com';

String formatInr(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  if (digits.length <= 3) return '₹$fixed';
  final last = digits.substring(digits.length - 3);
  var prefix = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (prefix.length > 2) {
    groups.insert(0, prefix.substring(prefix.length - 2));
    prefix = prefix.substring(0, prefix.length - 2);
  }
  if (prefix.isNotEmpty) groups.insert(0, prefix);
  return '₹${groups.join(',')},$last.${parts[1]}';
}

IconData categoryIcon(String slug) {
  if (slug.contains('beauty') || slug.contains('skin'))
    return Icons.spa_outlined;
  if (slug.contains('fragrance')) return Icons.water_drop_outlined;
  if (slug.contains('furniture')) return Icons.weekend_outlined;
  if (slug.contains('groceries') || slug.contains('food'))
    return Icons.local_grocery_store_outlined;
  if (slug.contains('laptop') || slug.contains('computer'))
    return Icons.laptop_outlined;
  if (slug.contains('mobile') || slug.contains('smartphone'))
    return Icons.smartphone_outlined;
  if (slug.contains('vehicle') || slug.contains('motorcycle'))
    return Icons.directions_car_outlined;
  if (slug.contains('watch')) return Icons.watch_outlined;
  if (slug.contains('jewellery')) return Icons.diamond_outlined;
  if (slug.contains('shirt') || slug.contains('tops'))
    return Icons.checkroom_outlined;
  if (slug.contains('shoe') || slug.contains('sandal'))
    return Icons.shopping_bag_outlined;
  if (slug.contains('lighting')) return Icons.lightbulb_outline;
  return Icons.category_outlined;
}

class Product {
  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.discountPercentage,
    required this.rating,
    required this.stock,
    required this.brand,
    required this.thumbnail,
    required this.images,
  });
  final int id;
  final String title;
  final String description;
  final String category;
  final double price;
  final double discountPercentage;
  final double rating;
  final int stock;
  final String brand;
  final String thumbnail;
  final List<String> images;

  factory Product.fromJson(Map<String, dynamic> json) {
    double number(dynamic value) => (value is num) ? value.toDouble() : 0;
    final images =
        (json['images'] as List?)?.whereType<String>().toList() ?? [];
    return Product(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Untitled product',
      description:
          json['description'] as String? ?? 'No description available.',
      category: json['category'] as String? ?? 'uncategorized',
      price: number(json['price']),
      discountPercentage: number(json['discountPercentage']),
      rating: number(json['rating']),
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      brand: json['brand'] as String? ?? 'ShopSphere',
      thumbnail:
          json['thumbnail'] as String? ?? (images.isEmpty ? '' : images.first),
      images: images,
    );
  }
}

class ProductPage {
  const ProductPage(this.products, this.total);
  final List<Product> products;
  final int total;
}

class Category {
  const Category(this.slug, this.name);
  final String slug;
  final String name;
  factory Category.fromJson(Map<String, dynamic> json) =>
      Category(json['slug'] as String? ?? '', json['name'] as String? ?? '');
}

class ApiClient {
  ApiClient()
    : dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (status) => status != null && status < 500,
        ),
      );
  final Dio dio;

  Future<ProductPage> products({
    int skip = 0,
    String? category,
    String? query,
  }) async {
    final path = query?.trim().isNotEmpty == true
        ? '/products/search'
        : category == null
        ? '/products'
        : '/products/category/$category';
    final response = await dio.get(
      path,
      queryParameters: {
        'limit': 12,
        'skip': skip,
        if (query?.trim().isNotEmpty == true) 'q': query!.trim(),
      },
    );
    final data = response.data;
    if (response.statusCode != 200 || data is! Map) {
      throw Exception('Unable to load products.');
    }
    final values = (data['products'] as List?) ?? [];
    return ProductPage(
      values
          .whereType<Map>()
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      (data['total'] as num?)?.toInt() ?? values.length,
    );
  }

  Future<Product> product(int id) async {
    final response = await dio.get('/products/$id');
    if (response.statusCode != 200 || response.data is! Map)
      throw Exception('Product not found.');
    return Product.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<Category>> categories() async {
    final response = await dio.get('/products/categories');
    if (response.statusCode != 200 || response.data is! List)
      throw Exception('Unable to load categories.');
    return (response.data as List)
        .whereType<Map>()
        .map((e) => Category.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

final apiProvider = Provider<ApiClient>((ref) => ApiClient());
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);
final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(apiProvider).categories(),
);
final featuredProvider = FutureProvider<List<Product>>(
  (ref) async =>
      (await ref.watch(apiProvider).products()).products.take(6).toList(),
);
final detailProvider = FutureProvider.family<Product, int>(
  (ref, id) => ref.watch(apiProvider).product(id),
);

class WishlistController extends StateNotifier<Set<int>> {
  WishlistController(this.prefs)
    : super({...prefs.getStringList('wishlist')?.map(int.parse) ?? <int>{}});
  final SharedPreferences prefs;
  void toggle(int id) {
    final updated = {...state};
    updated.contains(id) ? updated.remove(id) : updated.add(id);
    state = updated;
    prefs.setStringList('wishlist', updated.map((e) => e.toString()).toList());
  }
}

final wishlistProvider = StateNotifierProvider<WishlistController, Set<int>>(
  (ref) => WishlistController(ref.watch(prefsProvider)),
);

class CartLine {
  const CartLine({required this.product, required this.quantity});
  final Product product;
  final int quantity;

  Map<String, dynamic> toJson() => {
    'quantity': quantity,
    'product': {
      'id': product.id,
      'title': product.title,
      'description': product.description,
      'category': product.category,
      'price': product.price,
      'discountPercentage': product.discountPercentage,
      'rating': product.rating,
      'stock': product.stock,
      'brand': product.brand,
      'thumbnail': product.thumbnail,
      'images': product.images,
    },
  };

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    product: Product.fromJson(
      Map<String, dynamic>.from(json['product'] as Map),
    ),
  );
}

class CartController extends StateNotifier<List<CartLine>> {
  CartController(this.prefs) : super(_readCart(prefs));
  final SharedPreferences prefs;

  static List<CartLine> _readCart(SharedPreferences prefs) {
    final raw = prefs.getString('cart');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((item) => CartLine.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _save() => prefs.setString(
    'cart',
    jsonEncode(state.map((line) => line.toJson()).toList()),
  );

  void add(Product product) {
    final index = state.indexWhere((line) => line.product.id == product.id);
    if (index == -1) {
      state = [...state, CartLine(product: product, quantity: 1)];
    } else {
      final updated = [...state];
      final line = updated[index];
      updated[index] = CartLine(
        product: line.product,
        quantity: line.quantity + 1,
      );
      state = updated;
    }
    _save();
  }

  void decrement(int id) {
    final index = state.indexWhere((line) => line.product.id == id);
    if (index == -1) return;
    final line = state[index];
    if (line.quantity <= 1) {
      remove(id);
      return;
    }
    final updated = [...state];
    updated[index] = CartLine(
      product: line.product,
      quantity: line.quantity - 1,
    );
    state = updated;
    _save();
  }

  void remove(int id) {
    state = state.where((line) => line.product.id != id).toList();
    _save();
  }

  double get total =>
      state.fold(0, (sum, line) => sum + line.product.price * line.quantity);
}

final cartProvider = StateNotifierProvider<CartController, List<CartLine>>(
  (ref) => CartController(ref.watch(prefsProvider)),
);

class CatalogState {
  const CatalogState({
    this.products = const [],
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.total = 0,
    this.category,
  });
  final List<Product> products;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final int total;
  final String? category;
  CatalogState copyWith({
    List<Product>? products,
    bool? loading,
    bool? loadingMore,
    String? error,
    int? total,
    String? category,
  }) => CatalogState(
    products: products ?? this.products,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    error: error,
    total: total ?? this.total,
    category: category ?? this.category,
  );
}

class CatalogController extends StateNotifier<CatalogState> {
  CatalogController(this.api) : super(const CatalogState()) {
    load();
  }
  final ApiClient api;
  int _skip = 0;
  Future<void> load({String? category}) async {
    _skip = 0;
    state = CatalogState(loading: true, category: category);
    try {
      final page = await api.products(category: category);
      state = CatalogState(
        products: page.products,
        total: page.total,
        category: category,
      );
    } catch (_) {
      state = CatalogState(
        error: 'Could not load products. Check your connection and try again.',
        category: category,
      );
    }
  }

  Future<void> refresh() => load(category: state.category);
  Future<void> nextPage() async {
    if (state.loadingMore || state.products.length >= state.total) return;
    state = state.copyWith(loadingMore: true);
    try {
      _skip += 12;
      final page = await api.products(skip: _skip, category: state.category);
      final ids = state.products.map((p) => p.id).toSet();
      state = state.copyWith(
        products: [
          ...state.products,
          ...page.products.where((p) => ids.add(p.id)),
        ],
        loadingMore: false,
        total: page.total,
      );
    } catch (_) {
      state = state.copyWith(
        loadingMore: false,
        error: 'Could not load more products.',
      );
    }
  }
}

final catalogProvider = StateNotifierProvider<CatalogController, CatalogState>(
  (ref) => CatalogController(ref.watch(apiProvider)),
);

class SearchController extends StateNotifier<AsyncValue<List<Product>>> {
  SearchController(this.api) : super(const AsyncData([]));
  final ApiClient api;
  Timer? _timer;
  void search(String value) {
    _timer?.cancel();
    if (value.trim().isEmpty) {
      state = const AsyncData([]);
      return;
    }
    _timer = Timer(const Duration(milliseconds: 400), () async {
      state = const AsyncLoading();
      try {
        state = AsyncData((await api.products(query: value)).products);
      } catch (_) {
        state = AsyncError(
          'Search failed. Please try again.',
          StackTrace.current,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final searchProvider =
    StateNotifierProvider<SearchController, AsyncValue<List<Product>>>(
      (ref) => SearchController(ref.watch(apiProvider)),
    );

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const ShopSphereApp(),
    ),
  );
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/explore', builder: (_, __) => const CatalogScreen()),
    GoRoute(path: '/wishlist', builder: (_, __) => const WishlistScreen()),
    GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
    GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
    GoRoute(path: '/categories', builder: (_, __) => const CategoriesScreen()),
    GoRoute(
      path: '/product/:id',
      builder: (_, state) =>
          ProductDetailsScreen(id: int.parse(state.pathParameters['id']!)),
    ),
  ],
);

class ShopSphereApp extends StatelessWidget {
  const ShopSphereApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'ShopSphere',
    routerConfig: _router,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accent,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xfffffcf9),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}

class Shell extends StatelessWidget {
  const Shell({required this.index, required this.child, super.key});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) =>
          context.go(['/', '/explore', '/wishlist'][i]),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: 'Explore',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_border),
          selectedIcon: Icon(Icons.favorite),
          label: 'Wishlist',
        ),
      ],
    ),
  );
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Shell(
    index: 0,
    child: SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(featuredProvider),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.shopping_bag, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(
                  'ShopSphere',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => context.push('/search'),
                  icon: const Icon(Icons.search),
                ),
                const _CartButton(),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Find your next\nfavorite thing.',
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Curated products, delivered to your inspiration.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: () => context.push('/search'),
              borderRadius: BorderRadius.circular(16),
              child: const IgnorePointer(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search products',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            _SectionTitle(
              title: 'Featured products',
              action: 'View all',
              onTap: () => context.go('/explore'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 255,
              child: ref
                  .watch(featuredProvider)
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => _Message(
                      text: 'Unable to load featured products.',
                      retry: () => ref.invalidate(featuredProvider),
                    ),
                    data: (items) => ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (_, i) => SizedBox(
                        width: 175,
                        child: ProductCard(product: items[i]),
                      ),
                    ),
                  ),
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: 'Browse categories',
              action: 'See all',
              onTap: () => context.push('/categories'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ref
                  .watch(categoriesProvider)
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Text('Categories unavailable'),
                    data: (items) => ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.take(8).length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ActionChip(
                        avatar: Icon(categoryIcon(items[i].slug), size: 16),
                        label: Text(items[i].name),
                        onPressed: () {
                          ref
                              .read(catalogProvider.notifier)
                              .load(category: items[i].slug);
                          context.go('/explore');
                        },
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});
  @override
  ConsumerState<CatalogScreen> createState() => _CatalogState();
}

class _CatalogState extends ConsumerState<CatalogScreen> {
  final controller = ScrollController();
  String sort = 'Default';
  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      if (controller.position.extentAfter < 500)
        ref.read(catalogProvider.notifier).nextPage();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogProvider);
    var products = [...state.products];
    if (sort == 'Price: low')
      products.sort((a, b) => a.price.compareTo(b.price));
    if (sort == 'Price: high')
      products.sort((a, b) => b.price.compareTo(a.price));
    if (sort == 'Rating') products.sort((a, b) => b.rating.compareTo(a.rating));
    return Shell(
      index: 1,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Explore',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const _CartButton(),
                  IconButton(
                    onPressed: () => context.push('/search'),
                    icon: const Icon(Icons.search),
                  ),
                  PopupMenuButton<String>(
                    initialValue: sort,
                    onSelected: (v) => setState(() => sort = v),
                    itemBuilder: (_) =>
                        ['Default', 'Price: low', 'Price: high', 'Rating']
                            .map((v) => PopupMenuItem(value: v, child: Text(v)))
                            .toList(),
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
            ),
            if (state.category != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Chip(
                    label: Text(state.category!),
                    onDeleted: () => ref.read(catalogProvider.notifier).load(),
                  ),
                ),
              ),
            Expanded(
              child: state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null && products.isEmpty
                  ? _Message(
                      text: state.error!,
                      retry: () => ref.read(catalogProvider.notifier).refresh(),
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(catalogProvider.notifier).refresh(),
                      child: GridView.builder(
                        controller: controller,
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            products.length + (state.loadingMore ? 2 : 0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: .68,
                            ),
                        itemBuilder: (_, i) => i >= products.length
                            ? const Center(child: CircularProgressIndicator())
                            : ProductCard(product: products[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchState();
}

class _SearchState extends ConsumerState<SearchScreen> {
  final input = TextEditingController();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(searchProvider);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: input,
          autofocus: true,
          onChanged: ref.read(searchProvider.notifier).search,
          decoration: const InputDecoration(
            hintText: 'Search products',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(searchProvider.notifier).search(input.text),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          text: e.toString(),
          retry: () => ref.read(searchProvider.notifier).search(input.text),
        ),
        data: (items) => items.isEmpty
            ? const _Empty(
                icon: Icons.search_off,
                title: 'No matches yet',
                subtitle: 'Try searching for a product or brand.',
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: .68,
                ),
                itemBuilder: (_, i) => ProductCard(product: items[i]),
              ),
      ),
    );
  }
}

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Categories')),
    body: ref
        .watch(categoriesProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _Message(
            text: 'Could not load categories.',
            retry: () => ref.invalidate(categoriesProvider),
          ),
          data: (items) => ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _accent.withAlpha(25),
                  child: Icon(categoryIcon(items[i].slug), color: _accent),
                ),
                title: Text(items[i].name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ref
                      .read(catalogProvider.notifier)
                      .load(category: items[i].slug);
                  context.go('/explore');
                },
              ),
            ),
          ),
        ),
  );
}

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Shell(
    index: 2,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Wishlist',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final state = ref.watch(catalogProvider);
                if (state.loading)
                  return const Center(child: CircularProgressIndicator());
                final ids = ref.watch(wishlistProvider);
                final items = state.products
                    .where((p) => ids.contains(p.id))
                    .toList();
                return items.isEmpty
                    ? const _Empty(
                        icon: Icons.favorite_border,
                        title: 'Nothing saved yet',
                        subtitle: 'Tap the heart on products you love.',
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: .68,
                            ),
                        itemBuilder: (_, i) => ProductCard(product: items[i]),
                      );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(cartProvider);
    final cart = ref.read(cartProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Your cart')),
      body: lines.isEmpty
          ? const _Empty(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              subtitle: 'Add products to start shopping.',
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: lines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final line = lines[i];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: line.product.thumbnail,
                                  width: 78,
                                  height: 78,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.product.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      formatInr(line.product.price),
                                      style: const TextStyle(
                                        color: _accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () =>
                                              cart.decrement(line.product.id),
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                        ),
                                        Text(
                                          '${line.quantity}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              cart.add(line.product),
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove from cart',
                                onPressed: () => cart.remove(line.product.id),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0x11000000))),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              formatInr(cart.total),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: _accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Order ready'),
                                content: Text(
                                  'Your order total is ${formatInr(cart.total)}. Checkout is ready for integration.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Continue shopping'),
                                  ),
                                ],
                              ),
                            ),
                            icon: const Icon(Icons.lock_outline),
                            label: const Text('Proceed to buy'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CartButton extends ConsumerWidget {
  const _CartButton();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
        .watch(cartProvider)
        .fold<int>(0, (sum, line) => sum + line.quantity);
    return IconButton(
      tooltip: 'Cart',
      onPressed: () => context.push('/cart'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}

class ProductDetailsScreen extends ConsumerWidget {
  const ProductDetailsScreen({required this.id, super.key});
  final int id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(actions: [const _CartButton(), const SizedBox(width: 8)]),
    body: ref
        .watch(detailProvider(id))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _Message(
            text: 'Could not load this product.',
            retry: () => ref.invalidate(detailProvider(id)),
          ),
          data: (p) => _Details(product: p),
        ),
  );
}

class _Details extends ConsumerStatefulWidget {
  const _Details({required this.product});
  final Product product;
  @override
  ConsumerState<_Details> createState() => _DetailsState();
}

class _DetailsState extends ConsumerState<_Details> {
  int image = 0;
  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final wished = ref.watch(wishlistProvider).contains(p.id);
    final images = p.images.isEmpty ? [p.thumbnail] : p.images;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 1.1,
            child: CachedNetworkImage(
              imageUrl: images[image],
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.image_not_supported, size: 60),
            ),
          ),
        ),
        if (images.length > 1)
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => image = i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: images[i],
                    width: 65,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                p.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: () => ref.read(wishlistProvider.notifier).toggle(p.id),
              icon: Icon(
                wished ? Icons.favorite : Icons.favorite_border,
                color: wished ? Colors.red : null,
              ),
            ),
          ],
        ),
        Text(p.brand, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              formatInr(p.price),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            Chip(
              label: Text('${p.discountPercentage.toStringAsFixed(0)}% off'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber),
            Text(' ${p.rating.toStringAsFixed(1)}  •  ${p.stock} in stock'),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          p.description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 16),
        Chip(
          avatar: const Icon(Icons.sell_outlined, size: 16),
          label: Text(p.category),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () {
            ref.read(cartProvider.notifier).add(p);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Added to cart')));
          },
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Add to cart'),
        ),
      ],
    );
  }
}

class ProductCard extends ConsumerWidget {
  const ProductCard({required this.product, super.key});
  final Product product;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wished = ref.watch(wishlistProvider).contains(product.id);
    return InkWell(
      onTap: () => context.push('/product/${product.id}'),
      borderRadius: BorderRadius.circular(18),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        elevation: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: product.thumbnail,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const Center(child: Icon(Icons.image_not_supported)),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withAlpha(230),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => ref
                            .read(wishlistProvider.notifier)
                            .toggle(product.id),
                        icon: Icon(
                          wished ? Icons.favorite : Icons.favorite_border,
                          color: wished ? Colors.red : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        formatInr(product.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _accent,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Add to cart',
                        onPressed: () {
                          ref.read(cartProvider.notifier).add(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Added to cart')),
                          );
                        },
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                      ),
                      const Icon(Icons.star, size: 15, color: Colors.amber),
                      Text(
                        ' ${product.rating.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.action,
    required this.onTap,
  });
  final String title, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      const Spacer(),
      TextButton(onPressed: onTap, child: Text(action)),
    ],
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.retry});
  final String text;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.black38),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: Colors.black26),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ],
    ),
  );
}
