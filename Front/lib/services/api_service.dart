import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/coach_recommendation.dart';
import '../models/ejercicio.dart';
import '../models/entrenamiento.dart';
import '../models/nutricion.dart';
import '../models/rutina.dart';
import '../models/usuario.dart';

class ApiService {
  static const _baseUrl = 'http://10.0.2.2:8000/api';
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: queryParameters);
    final headers = {'Content-Type': 'application/json'};
    final response = await switch (method) {
      'GET' => _client.get(uri, headers: headers),
      'POST' => _client.post(uri, headers: headers, body: jsonEncode(body)),
      _ => throw ArgumentError('Método HTTP no soportado: $method'),
    };

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final error = payload['error'] as Map<String, dynamic>?;
      throw ApiException(error?['message']?.toString() ?? 'Error de servidor');
    }

    final data = payload['data'];
    if (data == null) {
      throw ApiException('La respuesta no contiene datos válidos');
    }
    return data as Map<String, dynamic>;
  }

  Future<Usuario> getUsuario(int idUsuario) async {
    final data = await _request('GET', '/usuarios/$idUsuario');
    return Usuario.fromJson(data);
  }

  Future<List<Rutina>> getRutinas(int idUsuario) async {
    final data = await _request('GET', '/usuarios/$idUsuario/rutinas');
    final list = data['rutinas'] as List<dynamic>;
    return list.map((item) => Rutina.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<Ejercicio>> getEjercicios() async {
    final data = await _request('GET', '/ejercicios');
    final list = data['ejercicios'] as List<dynamic>;
    return list.map((item) => Ejercicio.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<Nutricion>> getNutricion(int idUsuario) async {
    final data = await _request('GET', '/usuarios/$idUsuario/nutricion');
    final list = data['nutricion'] as List<dynamic>;
    return list.map((item) => Nutricion.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<Entrenamiento>> getEntrenamientos(int idUsuario) async {
    final data = await _request('GET', '/usuarios/$idUsuario/entrenamientos');
    final list = data['entrenamientos'] as List<dynamic>;
    return list.map((item) => Entrenamiento.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<CoachRecommendation> getCoachRecommendation(int idUsuario) async {
    final data = await _request('GET', '/coach/recomendaciones', queryParameters: {'id_usuario': idUsuario.toString()});
    return CoachRecommendation.fromJson(data);
  }

  Future<void> registrarNutricion(int idUsuario, Nutricion nutricion) async {
    await _request(
      'POST',
      '/usuarios/$idUsuario/nutricion',
      body: nutricion.toJson(),
    );
  }

  Future<void> registrarEntrenamiento(int idUsuario, Entrenamiento entrenamiento) async {
    await _request(
      'POST',
      '/usuarios/$idUsuario/entrenamientos',
      body: entrenamiento.toPostJson(),
    );
  }
}

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
