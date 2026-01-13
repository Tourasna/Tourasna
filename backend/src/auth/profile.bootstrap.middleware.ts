import { prisma } from '../db/prisma';

export async function ensureProfile(req, res, next) {
  const auth = req.auth;
  if (!auth?.sub) return next();

  // ❗ Skip machine tokens (client credentials)
  if (!auth.email) {
    return next();
  }

  const userId = auth.sub;

  const exists = await prisma.profile.findUnique({
    where: { id: userId },
  });

  if (!exists) {
    await prisma.profile.create({
      data: {
        id: userId,
        email: auth.email,
        name: auth.name ?? null,
      },
    });
  }

  next();
}
