import * as admin from 'firebase-admin';
import * as path from 'path';

const serviceAccountPath = path.join(
  process.cwd(),
  'serviceAccount.json',
);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(
      require(serviceAccountPath),
    ),
  });
}

export { admin };
