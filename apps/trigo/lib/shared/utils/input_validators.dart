import 'package:flutter/material.dart';

/// Reusable validator functions returning an error message (or null when the
/// value is valid) for use with [Form] fields.
class InputValidators {
  static String? required(String? value, [String? message]) {
    if (value == null || value.trim().isEmpty) {
      return message ?? 'This field is required';
    }
    return null;
  }

  static String? email(String? value, [String? message]) {
    if (value == null || value.trim().isEmpty) {
      return message ?? 'Email is required';
    }
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (!regex.hasMatch(value.trim())) {
      return message ?? 'Enter a valid email address';
    }
    return null;
  }

  static String? minLength(int min, String? value, [String? message]) {
    if (value == null || value.trim().length < min) {
      return message ?? 'Must be at least $min characters';
    }
    return null;
  }

  static String? phone(String? value, [String? message]) {
    if (value == null || value.trim().isEmpty) {
      return message ?? 'Phone number is required';
    }
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) {
      return message ?? 'Enter a valid phone number';
    }
    return null;
  }

  /// For confirm-password fields: [other] is the original password value.
  static String? matches(String? other, String? value, [String? message]) {
    if (value == null || value.isEmpty) {
      return message ?? 'Please confirm your password';
    }
    if (value != other) {
      return message ?? 'Passwords do not match';
    }
    return null;
  }

  static String? driverLicense(String? value, [String? message]) {
    return minLength(3, value, message ?? 'Enter your driver license number');
  }

  static String? plateNumber(String? value, [String? message]) {
    return minLength(3, value, message ?? 'Enter your tricycle plate number');
  }
}