// this is stupid but necessary, because to support google sign-in on web
// you need the renderButton function from the google_sign_in_web package,
// wich you can only import if you are compiling for web, otherwise it will
// throw an compilation error

// to prevent this compilation error, you have to use conditional imports
// wich leads to this extra 3 files
export 'stub.dart' if (dart.library.js_util) 'on_web.dart';

// the thing is that this isn't written anywhere in the documentation
// and i found this solution only in the example code
//https://github.com/flutter/packages/blob/main/packages/google_sign_in/google_sign_in/example/lib/main.dart

// PS: the AI had understood the error but advised to delete the import and renderButton call
// entirely wich would lead to a non working google sign-in on web
