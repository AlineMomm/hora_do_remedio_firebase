// lib/services/firebase_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';
import '../models/medication_model.dart';
import '../firebase_options.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Usar late final para garantir que só serão inicializadas depois
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;

  // Getters que garantem que as instâncias estão inicializadas
  FirebaseAuth get auth {
    if (!_isInitialized) _initInstances();
    return _auth;
  }
  
  FirebaseFirestore get firestore {
    if (!_isInitialized) _initInstances();
    return _firestore;
  }
  
  User? get currentUser {
    if (!_isInitialized) _initInstances();
    return _auth.currentUser;
  }
  
  bool get isSignedIn {
    if (!_isInitialized) _initInstances();
    return _auth.currentUser != null;
  }

  bool _isInitialized = false;

  // ==================== INICIALIZAÇÃO ====================
  static Future<void> initialize() async {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;

      // Inicializar o Firebase primeiro
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
        print('✅ Firebase.initializeApp() executado');
      } else {
        print('ℹ️ Firebase já inicializado, ignorando reinit');
      }

      // Configurações específicas para web
      if (kIsWeb) {
        await _configureWebAuth();
      }

      // Agora sim, inicializar a instância singleton
      _instance._initInstances();
      
      print('✅ Firebase inicializado com sucesso (${kIsWeb ? "Web" : "Android"})');
    } catch (e) {
      print('❌ Erro ao inicializar Firebase: $e');
      rethrow;
    }
  }

  // Inicializar as instâncias APÓS o Firebase.initializeApp()
  void _initInstances() {
    if (!_isInitialized) {
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _isInitialized = true;
      print('✅ Instâncias do Firebase inicializadas');
    }
  }

  // Configurações adicionais para web
  static Future<void> _configureWebAuth() async {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

  // ==================== AUTENTICAÇÃO ====================
  Future<UserModel?> registerWithEmailAndPassword(
    String name,
    String email,
    String password,
  ) async {
    try {
      // Garantir que as instâncias estão inicializadas
      if (!_isInitialized) _initInstances();
      
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) throw 'Erro ao criar usuário';

      await user.updateDisplayName(name);
      await user.reload();

      final userModel = UserModel(
        uid: user.uid,
        name: name,
        email: email,
      );

      await _firestore.collection('users').doc(user.uid).set(userModel.toMap());

      print('✅ Usuário criado no Firebase: ${user.uid}');
      return userModel;
    } on FirebaseAuthException catch (e) {
      print('❌ Erro Firebase: ${e.code} - ${e.message}');
      if (e.code == 'email-already-in-use') {
        throw 'Este e-mail já está cadastrado';
      } else if (e.code == 'weak-password') {
        throw 'Senha muito fraca (mínimo 6 caracteres)';
      } else {
        throw 'Erro no cadastro: ${e.message}';
      }
    } catch (e) {
      print('❌ Erro no registro: $e');
      throw 'Erro no cadastro: $e';
    }
  }

  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      // Garantir que as instâncias estão inicializadas
      if (!_isInitialized) _initInstances();
      
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user == null) throw 'Usuário não encontrado';

      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (!doc.exists) {
        final userModel = UserModel(
          uid: user.uid,
          name: user.displayName ?? 'Usuário',
          email: user.email!,
        );
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toMap());
        return userModel;
      }

      return UserModel.fromMap(doc.data()!);
    } on FirebaseAuthException catch (e) {
      print('❌ Erro Firebase: ${e.code} - ${e.message}');
      if (e.code == 'user-not-found') {
        throw 'Usuário não encontrado';
      } else if (e.code == 'wrong-password') {
        throw 'Senha incorreta';
      } else if (e.code == 'invalid-email') {
        throw 'E-mail inválido';
      } else {
        throw 'Erro no login: ${e.message}';
      }
    } catch (e) {
      print('❌ Erro no login: $e');
      throw 'Erro no login: $e';
    }
  }

  Future<void> signOut() async {
    try {
      if (!_isInitialized) _initInstances();
      await _auth.signOut();
    } catch (e) {
      print('❌ Erro ao fazer logout: $e');
    }
  }

  // ==================== MEDICAMENTOS ====================
  Future<void> syncMedicationsToCloud(
      String userId, List<MedicationModel> medications) async {
    try {
      if (!_isInitialized) _initInstances();
      
      final batch = _firestore.batch();
      final userMedsRef =
          _firestore.collection('users').doc(userId).collection('medications');

      final existingSnapshot = await userMedsRef.get();

      for (var doc in existingSnapshot.docs) {
        batch.delete(doc.reference);
      }

      for (var med in medications) {
        final docRef = userMedsRef.doc(med.id);
        batch.set(docRef, {
          ...med.toMap(),
          'lastSync': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('✅ Medicamentos sincronizados: ${medications.length}');
    } catch (e) {
      print('❌ Erro ao sincronizar: $e');
      throw 'Erro ao sincronizar com a nuvem';
    }
  }

  Future<List<MedicationModel>> loadMedicationsFromCloud(String userId) async {
    try {
      if (!_isInitialized) _initInstances();
      
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('medications')
          .orderBy('createdAt', descending: true)
          .get();

      final medications = snapshot.docs.map((doc) {
        return MedicationModel.fromMap(doc.data());
      }).toList();

      print('✅ Medicamentos carregados da nuvem: ${medications.length}');
      return medications;
    } catch (e) {
      print('❌ Erro ao carregar da nuvem: $e');
      throw 'Erro ao carregar dados da nuvem';
    }
  }

  // ==================== PERFIL ====================
  Future<void> updateUserProfile(UserModel user) async {
  try {
    if (!_isInitialized) _initInstances();

    await _firestore.collection('users').doc(user.uid).set(
      user.toMap(),
      SetOptions(merge: true),
    );

    print('✅ Perfil atualizado no Firebase: ${user.uid}');
  } catch (e) {
    print('❌ Erro ao atualizar perfil: $e');
    throw 'Erro ao atualizar perfil na nuvem';
  }
}

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      if (!_isInitialized) _initInstances();
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ Erro ao buscar perfil: $e');
      return null;
    }
  }
}