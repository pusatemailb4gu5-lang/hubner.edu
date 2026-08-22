import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

class GoogleSignInWebButton extends StatelessWidget {
  const GoogleSignInWebButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: web.renderButton(
        configuration: web.GSIButtonConfiguration(
          type: web.GSIButtonType.standard,
          shape: web.GSIButtonShape.pill,
          size: web.GSIButtonSize.large,
          text: web.GSIButtonText.signinWith,
          theme: web.GSIButtonTheme.outline,
        ),
      ),
    );
  }
}
