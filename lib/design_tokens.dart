// ============================================
// YALLA NEMSHI - DESIGN TOKENS (v2 - Hybrid Approach)
// ============================================
// Color Strategy: Active, Connected, Explored
// Primary: Teal (movement, trust, connection)
// Secondary: Coral (urgency, alerts, private)
// Accent: Lime (success, join, go)
// Base: Green (secondary, nature, heritage)
// ============================================

import 'package:flutter/material.dart';

// ===== PRIMARY COLORS =====
/// Vibrant Teal - CTAs, active states, primary interactions
const Color kPrimaryTeal = Color(0xFF1ABFC4);
const Color kPrimaryTealDark = Color(0xFF0A9DA5);
const Color kPrimaryTealLight = Color(0xFF5CDFEB);

// ===== SECONDARY COLORS =====
/// Warm Coral - Alerts, private walks, host badges
const Color kSecondaryCorall = Color(0xFFFF6B6B);
const Color kSecondaryCoralDark = Color(0xFFE85555);
const Color kSecondaryCoralLight = Color(0xFFFF9999);

// ===== ACCENT COLORS =====
/// Fresh Lime Green - Success, join actions, completion
const Color kAccentLime = Color(0xFF00D97E);
const Color kAccentLimeDark = Color(0xFF00A861);
const Color kAccentLimeLight = Color(0xFF5CFF9F);

// ===== BASE GREENS (Heritage - keeping for secondary use) =====
/// Deep green - used for selected states, secondary buttons
const Color kGreenDeep = Color(0xFF14532D);
const Color kGreenDark = Color(0xFF0F3D21);
const Color kGreenLight = Color(0xFF2E7D32);

/// Mint green - walk day indicators, secondary accents
const Color kGreenMint = Color(0xFFA4E4C5);
const Color kGreenMintBright = Color(0xFF9BD77A);
const Color kGreenMintLight = Color(0xFFE8F1EA);

/// Green primary (header gradient)
const Color kGreenPrimary = Color(0xFF4F925C);

// ===== NEUTRALS & BACKGROUNDS =====
/// Soft Off-White - Main backgrounds (reduces eye strain)
const Color kBackgroundLight = Color(0xFFFAFBFC);
const Color kBackgroundLightWarm = Color(0xFFF8F9FB);
const Color kBackgroundLightAlt = Color(0xFFF7F3EA);
const Color kSurfaceLight = Color(0xFFFBFEF8);

/// Dark backgrounds
const Color kBackgroundDark = Color(0xFF071B26);
const Color kBackgroundDarkAlt = Color(0xFF041016);
const Color kSurfaceDark = Color(0xFF0C2430);

// ===== TEXT COLORS =====
/// Deep Navy - Headlines, primary text
const Color kTextNavy = Color(0xFF1A2332);

/// Muted Gray - Secondary text, descriptions
const Color kTextMuted = Color(0xFF6B7280);

/// Light Gray - Tertiary text, borders
const Color kTextLight = Color(0xFFE5E7EB);

// ===== LEGACY/COMPAT CONSTANTS (mapped to new system) =====
/// Use kPrimaryTeal instead
const Color kMintBright = kGreenMintBright;

/// Use kBackgroundDark instead
const Color kDarkBg = kBackgroundDark;

/// Use kSurfaceDark instead
const Color kDarkSurface = kSurfaceDark;

/// Use kSurfaceLight instead
const Color kLightSurface = kSurfaceLight;

/// Use kTextNavy instead
const Color kTextPrimary = kTextNavy;

/// Use kOnMint for legacy support
const Color kOnMint = Color(0xFFFFFFFF);

// ===== UTILITY FUNCTIONS =====
/// Get text color based on theme
Color getTextColor(bool isDark) => isDark ? Colors.white : kTextNavy;

/// Get surface color based on theme
Color getSurfaceColor(bool isDark) => isDark ? kSurfaceDark : kSurfaceLight;

/// Get background color based on theme
Color getBackgroundColor(bool isDark) => isDark ? kBackgroundDark : kBackgroundLight;

/// Get primary action color (Teal - new design)
Color getPrimaryActionColor(bool isDark) => isDark ? kPrimaryTeal : kPrimaryTeal;

/// Get success color (Lime - new design)
Color getSuccessColor(bool isDark) => isDark ? kAccentLime : kAccentLime;

/// Get alert color (Coral - new design)
Color getAlertColor(bool isDark) => isDark ? kSecondaryCorall : kSecondaryCorall;
