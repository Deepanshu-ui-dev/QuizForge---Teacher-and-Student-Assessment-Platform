import 'dart:io';
import 'package:dio/dio.dart';
import 'failure.dart';

class FailureMapper {
  FailureMapper._();

  static Failure fromException(Object error) {
    if (error is Failure) return error;

    if (error is DioException) {
      return _fromDioException(error);
    }

    if (error is SocketException) {
      return const NetworkFailure();
    }

    return const UnknownFailure();
  }

  static Failure _fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure('The server is taking too long to respond. Please try again.');
      case DioExceptionType.connectionError:
        return const NetworkFailure("Can't reach the server. Check your connection and try again.");
      case DioExceptionType.badCertificate:
        return const NetworkFailure('Could not establish a secure connection.');
      case DioExceptionType.cancel:
        return const UnknownFailure('Request was cancelled.');
      case DioExceptionType.badResponse:
        return _fromResponse(e);
      case DioExceptionType.unknown:
        if (e.error is SocketException) return const NetworkFailure();
        return const UnknownFailure();
      default:
        return const UnknownFailure();
    }
  }

  static Failure _fromResponse(DioException e) {
    final response = e.response;
    final statusCode = response?.statusCode ?? 0;
    final data = response?.data;

    String? serverMessage;
    if (data is Map && data['message'] is String && (data['message'] as String).isNotEmpty) {
      serverMessage = data['message'] as String;
    }

    switch (statusCode) {
      case 400:
      case 409:
      case 422:
        return ValidationFailure(serverMessage ?? 'Please check your input and try again.');
      case 401:
        return UnauthorizedFailure(serverMessage ?? 'Your session has expired. Please log in again.');
      case 403:
        return ServerFailure(statusCode, "You don't have permission to do that.");
      case 404:
        return ServerFailure(statusCode, serverMessage ?? "We couldn't find what you were looking for.");
      case 429:
        return ServerFailure(statusCode, 'Too many requests. Please wait a moment and try again.');
      default:
        // Never surface raw "Internal Server Error" / stack-ish messages.
        if (statusCode >= 500) {
          return ServerFailure(statusCode, 'The server ran into a problem. Please try again shortly.');
        }
        return ServerFailure(statusCode, serverMessage ?? 'Something went wrong. Please try again.');
    }
  }
}
