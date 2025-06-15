import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class ModelService {
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isModelLoaded = false;

  // Model dosya yolları
  static const String _modelPath = 'assets/models/plant_disease_model.tflite';
  static const String _labelsPath = 'assets/models/labels.txt';

  // Model giriş boyutları
  static const int _inputSize = 224;
  static const int _numChannels = 3;

  Future<void> initializeModel() async {
    try {
      // Model dosyasını yükle
      _interpreter = await Interpreter.fromAsset(_modelPath);
      
      // Etiketleri yükle
      await _loadLabels();
      
      _isModelLoaded = true;
      print('Model başarıyla yüklendi');
    } catch (e) {
      print('Model yükleme hatası: $e');
      throw Exception('Model yüklenemedi: $e');
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelsData = await rootBundle.loadString(_labelsPath);
      _labels = labelsData.split('\n').where((line) => line.trim().isNotEmpty).toList();
      print('${_labels!.length} etiket yüklendi');
    } catch (e) {
      print('Etiket yükleme hatası: $e');
      // Varsayılan etiketler - gerçek uygulamada assets klasöründe labels.txt dosyası olmalı
      _labels = _getDefaultLabels();
    }
  }

  List<String> _getDefaultLabels() {
    return [
      'Apple___Apple_scab',
      'Apple___Black_rot',
      'Apple___Cedar_apple_rust',
      'Apple___healthy',
      'Blueberry___healthy',
      'Cherry_(including_sour)___Powdery_mildew',
      'Cherry_(including_sour)___healthy',
      'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot',
      'Corn_(maize)___Common_rust_',
      'Corn_(maize)___Northern_Leaf_Blight',
      'Corn_(maize)___healthy',
      'Grape___Black_rot',
      'Grape___Esca_(Black_Measles)',
      'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)',
      'Grape___healthy',
      'Orange___Haunglongbing_(Citrus_greening)',
      'Peach___Bacterial_spot',
      'Peach___healthy',
      'Pepper,_bell___Bacterial_spot',
      'Pepper,_bell___healthy',
      'Potato___Early_blight',
      'Potato___Late_blight',
      'Potato___healthy',
      'Raspberry___healthy',
      'Soybean___healthy',
      'Squash___Powdery_mildew',
      'Strawberry___Leaf_scorch',
      'Strawberry___healthy',
      'Tomato___Bacterial_spot',
      'Tomato___Early_blight',
      'Tomato___Late_blight',
      'Tomato___Leaf_Mold',
      'Tomato___Septoria_leaf_spot',
      'Tomato___Spider_mites Two-spotted_spider_mite',
      'Tomato___Target_Spot',
      'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
      'Tomato___Tomato_mosaic_virus',
      'Tomato___healthy'
    ];
  }

  Future<AnalysisResult> analyzeImage(File imageFile) async {
    if (!_isModelLoaded || _interpreter == null || _labels == null) {
      throw Exception('Model henüz yüklenmedi');
    }

    try {
      // Görüntüyü ön işle
      final input = await _preprocessImage(imageFile);
      
      // Model çıktısı için buffer oluştur
      final output = List.filled(_labels!.length, 0.0).reshape([1, _labels!.length]);
      
      // Tahmin yap
      _interpreter!.run(input, output);
      
      // Sonuçları işle
      final predictions = output[0] as List<double>;
      final result = _processResults(predictions);
      
      return result;
    } catch (e) {
      print('Analiz hatası: $e');
      throw Exception('Görüntü analiz edilemedi: $e');
    }
  }

  Future<List<List<List<List<double>>>>> _preprocessImage(File imageFile) async {
    // Görüntüyü oku
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) {
      throw Exception('Görüntü decode edilemedi');
    }

    // Görüntüyü yeniden boyutlandır
    final resized = img.copyResize(image, width: _inputSize, height: _inputSize);
    
    // Tensör formatına dönüştür
    final input = List.generate(
      1,
      (i) => List.generate(
        _inputSize,
        (j) => List.generate(
          _inputSize,
          (k) => List.generate(_numChannels, (l) {
            final pixel = resized.getPixel(k, j);
            switch (l) {
              case 0:
                return pixel.r / 255.0; // Red
              case 1:
                return pixel.g / 255.0; // Green
              case 2:
                return pixel.b / 255.0; // Blue
              default:
                return 0.0;
            }
          }),
        ),
      ),
    );

    return input;
  }

  AnalysisResult _processResults(List<double> predictions) {
    // En yüksek olasılığa sahip sınıfı bul
    double maxConfidence = 0.0;
    int maxIndex = 0;
    
    for (int i = 0; i < predictions.length; i++) {
      if (predictions[i] > maxConfidence) {
        maxConfidence = predictions[i];
        maxIndex = i;
      }
    }

    final className = _labels![maxIndex];
    final diseaseInfo = _getDiseaseInfo(className);
    final isHealthy = className.toLowerCase().contains('healthy');

    return AnalysisResult(
      confidence: maxConfidence,
      info: diseaseInfo,
      isHealthy: isHealthy,
    );
  }

  DiseaseInfo _getDiseaseInfo(String className) {
    // Sınıf adından hastalık bilgilerini çıkar
    final parts = className.split('___');
    final plant = parts.isNotEmpty ? parts[0] : 'Bilinmeyen Bitki';
    final disease = parts.length > 1 ? parts[1] : 'Bilinmeyen Durum';
    
    final isHealthy = disease.toLowerCase().contains('healthy');
    
    if (isHealthy) {
      return DiseaseInfo(
        trName: '$plant - Sağlıklı',
        description: 'Bitkide herhangi bir hastalık belirtisi tespit edilmedi. Bitki sağlıklı görünüyor.',
        solution: 'Bitkinin mevcut bakım rutinini sürdürün. Düzenli sulama, uygun gübre ve ışık koşullarını koruyun.',
      );
    }

    // Hastalık tipine göre Türkçe bilgi döndür
    return _getSpecificDiseaseInfo(plant, disease);
  }

  DiseaseInfo _getSpecificDiseaseInfo(String plant, String disease) {
    final diseaseMap = <String, DiseaseInfo>{
      'Apple_scab': DiseaseInfo(
        trName: 'Elma - Elma Karalekesi',
        description: 'Elma karalekesi, yaprak ve meyvelerde koyu lekeler oluşturan fungal bir hastalıktır.',
        solution: 'Fungisit uygulayın, budama yapın ve hava sirkülasyonunu artırın.',
      ),
      'Black_rot': DiseaseInfo(
        trName: '$plant - Siyah Çürüklük',
        description: 'Siyah çürüklük, meyve ve yapraklarda kahverengi-siyah lekeler oluşturan fungal bir hastalıktır.',
        solution: 'Etkilenen kısımları kesin, fungisit uygulayın ve temiz bahçe hijyeni sağlayın.',
      ),
      'Cedar_apple_rust': DiseaseInfo(
        trName: 'Elma - Sedir Elma Pası',
        description: 'Yapraklarda turuncu lekeler ve sporlar oluşturan fungal bir hastalıktır.',
        solution: 'Fungisit spreyi yapın ve ardıç ağaçlarını yakın çevreden uzaklaştırın.',
      ),
      'Powdery_mildew': DiseaseInfo(
        trName: '$plant - Külleme',
        description: 'Yaprak yüzeyinde beyaz pudra görünümünde fungal gelişim.',
        solution: 'Hava sirkülasyonunu artırın, fungisit uygulayın ve aşırı nemlenmeden kaçının.',
      ),
      'Early_blight': DiseaseInfo(
        trName: '$plant - Erken Yanıklık',
        description: 'Yapraklarda koyu kahverengi, konsantrik halkalı lekeler oluşturan fungal hastalık.',
        solution: 'Düzenli fungisit uygulaması yapın, sulama sırasında yaprakları ıslatmaktan kaçının.',
      ),
      'Late_blight': DiseaseInfo(
        trName: '$plant - Geç Yanıklık',
        description: 'Yaprak ve meyvede hızla yayılan, koyu lekeler oluşturan ciddi fungal hastalık.',
        solution: 'Derhal fungisit uygulayın, etkilenen bitkileri imha edin ve hava sirkülasyonunu artırın.',
      ),
      'Bacterial_spot': DiseaseInfo(
        trName: '$plant - Bakteriyel Leke',
        description: 'Yaprak ve meyvelerde küçük, koyu lekeler oluşturan bakteriyel enfeksiyon.',
        solution: 'Bakır bazlı bakterisit uygulayın, etkilenen kısımları temizleyin ve aşırı nemlenmeden kaçının.',
      ),
    };

    // Hastalık adını temizle ve eşleştir
    final cleanDisease = disease.replaceAll('_', ' ').replaceAll('(', '').replaceAll(')', '');
    
    for (final key in diseaseMap.keys) {
      if (disease.contains(key.replaceAll('_', ' ')) || 
          cleanDisease.toLowerCase().contains(key.toLowerCase().replaceAll('_', ' '))) {
        return diseaseMap[key]!;
      }
    }

    // Varsayılan bilgi
    return DiseaseInfo(
      trName: '$plant - ${disease.replaceAll('_', ' ')}',
      description: 'Bu hastalık hakkında detaylı bilgi mevcut değil. Genel bitki hastalığı belirtileri görülmektedir.',
      solution: 'Bir tarım uzmanına danışın, etkilenen kısımları temizleyin ve uygun ilaçlama yapın.',
    );
  }

  static String getConfidenceMessage(double confidence) {
    if (confidence >= 0.9) return 'Çok yüksek güvenilirlik';
    if (confidence >= 0.8) return 'Yüksek güvenilirlik';
    if (confidence >= 0.7) return 'Orta-yüksek güvenilirlik';
    if (confidence >= 0.6) return 'Orta güvenilirlik';
    if (confidence >= 0.5) return 'Düşük-orta güvenilirlik';
    return 'Düşük güvenilirlik - Uzman görüşü önerilir';
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _labels = null;
    _isModelLoaded = false;
  }
}

class AnalysisResult {
  final double confidence;
  final DiseaseInfo info;
  final bool isHealthy;

  AnalysisResult({
    required this.confidence,
    required this.info,
    required this.isHealthy,
  });
}

class DiseaseInfo {
  final String trName;
  final String description;
  final String solution;

  DiseaseInfo({
    required this.trName,
    required this.description,
    required this.solution,
  });
}

