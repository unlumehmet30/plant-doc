import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'model_service.dart';

void main() {
  runApp(const PlantDoctorApp());
}

class PlantDoctorApp extends StatelessWidget {
  const PlantDoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bitki Doktoru',
      theme: _buildTheme(),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.light,
      ),
      fontFamily: 'Roboto',
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme:const CardThemeData(
        elevation: 4,
        margin:  EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  final ModelService _modelService = ModelService();
  
  bool _isAnalyzing = false;
  bool _isModelLoading = false;
  AnalysisResult? _analysisResult;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _requestPermissions();
    _loadModel();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _modelService.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.photos,
      Permission.storage,
    ].request();
  }

  Future<void> _loadModel() async {
    setState(() => _isModelLoading = true);

    try {
      await _modelService.initializeModel();
      if (mounted) {
        setState(() => _isModelLoading = false);
        _showSnackBar('Model başarıyla yüklendi!', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isModelLoading = false);
        _showSnackBar('Model yüklenemedi: $e', Colors.orange);
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _analysisResult = null;
        });
        _animateImageSelection();
      }
    } catch (e) {
      _showSnackBar('Kamera erişiminde hata: $e', Colors.red);
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _analysisResult = null;
        });
        _animateImageSelection();
      }
    } catch (e) {
      _showSnackBar('Galeri erişiminde hata: $e', Colors.red);
    }
  }

  void _animateImageSelection() {
    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null || _isModelLoading) return;

    setState(() => _isAnalyzing = true);

    try {
      final result = await _modelService.analyzeImage(_selectedImage!);
      
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisResult = result;
        });
        _animateImageSelection();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        _showSnackBar('Analiz hatası: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: _buildAppBar(theme),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primaryContainer.withOpacity(0.3),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWelcomeCard(theme),
                const SizedBox(height: 24),
                Expanded(
                  flex: 2,
                  child: _buildImageDisplayArea(theme),
                ),
                const SizedBox(height: 16),
                if (_analysisResult != null) ...[
                  _buildAnalysisResult(theme),
                  const SizedBox(height: 16),
                ],
                _buildActionButtons(theme),
                const SizedBox(height: 16),
                _buildAnalyzeButton(theme),
                const SizedBox(height: 8),
                _buildInfoText(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      title: Row(
        children: [
          Icon(Icons.local_florist, color: theme.colorScheme.onPrimary),
          const SizedBox(width: 8),
          const Text(
            'Bitki Doktoru',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      elevation: 0,
      actions: [
        if (_isModelLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWelcomeCard(ThemeData theme) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withOpacity(0.8),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.local_florist,
                size: 48,
                color: theme.colorScheme.onPrimary,
              ),
              const SizedBox(height: 12),
              Text(
                'Bitkinin fotoğrafını çekerek\nYapay Zeka ile hastalık analizi yapın',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (_isModelLoading) ...[
                const SizedBox(height: 12),
                Text(
                  'MobileNetV2 modeli yükleniyor...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimary.withOpacity(0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageDisplayArea(ThemeData theme) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.5),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _selectedImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Fotoğraf çekin veya galeriden seçin',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildAnalysisResult(ThemeData theme) {
    if (_analysisResult == null) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultHeader(theme),
              const SizedBox(height: 16),
              _buildDiseaseInfo(theme),
              const SizedBox(height: 16),
              _buildDescription(theme),
              const SizedBox(height: 16),
              _buildSolution(theme),
              const SizedBox(height: 16),
              _buildConfidenceInfo(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultHeader(ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _analysisResult!.isHealthy
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _analysisResult!.isHealthy ? Icons.check_circle : Icons.warning,
            color: _analysisResult!.isHealthy
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onErrorContainer,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analiz Sonucu',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'MobileNetV2 AI Model',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiseaseInfo(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _analysisResult!.isHealthy
            ? theme.colorScheme.primaryContainer.withOpacity(0.5)
            : theme.colorScheme.errorContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _analysisResult!.isHealthy
              ? theme.colorScheme.primary.withOpacity(0.3)
              : theme.colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Text(
        _analysisResult!.info.trName,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: _analysisResult!.isHealthy
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onErrorContainer,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDescription(ThemeData theme) {
    return _buildInfoContainer(
      theme: theme,
      icon: Icons.info_outline,
      title: 'Açıklama',
      content: _analysisResult!.info.description,
    );
  }

  Widget _buildSolution(ThemeData theme) {
    return _buildInfoContainer(
      theme: theme,
      icon: Icons.lightbulb_outline,
      title: 'Öneriler',
      content: _analysisResult!.info.solution,
      backgroundColor: theme.colorScheme.tertiaryContainer.withOpacity(0.5),
      borderColor: theme.colorScheme.tertiary.withOpacity(0.3),
      iconColor: theme.colorScheme.tertiary,
    );
  }

  Widget _buildInfoContainer({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String content,
    Color? backgroundColor,
    Color? borderColor,
    Color? iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ?? theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: iconColor ?? theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '$title:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceInfo(ThemeData theme) {
    final confidence = _analysisResult!.confidence;
    final confidenceColor = _getConfidenceColor(confidence);
    
    return Row(
      children: [
        Icon(
          Icons.analytics_outlined,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          'Güvenilirlik: ',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: confidenceColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: confidenceColor.withOpacity(0.3),
            ),
          ),
          child: Text(
            '${(confidence * 100).toInt()}%',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: confidenceColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            ModelService.getConfidenceMessage(confidence),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _pickImageFromCamera,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Fotoğraf Çek'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: _pickImageFromGallery,
            icon: const Icon(Icons.photo_library),
            label: const Text('Galeriden Seç'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton(ThemeData theme) {
    final isEnabled = _selectedImage != null && !_isAnalyzing && !_isModelLoading;
    
    return FilledButton.icon(
      onPressed: isEnabled ? _analyzeImage : null,
      icon: _isAnalyzing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.psychology),
      label: Text(
        _isAnalyzing
            ? 'AI Analiz Yapıyor...'
            : _isModelLoading
                ? 'Model Yükleniyor...'
                : 'AI ile Hastalığı Tespit Et',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildInfoText(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        'Bu uygulama MobileNetV2 AI modeli kullanarak bitki hastalıklarını tespit eder. '
        'Sonuçlar referans amaçlıdır, kesin teşhis için uzman görüşü alın.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
