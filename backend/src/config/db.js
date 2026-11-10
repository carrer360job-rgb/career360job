import { PrismaClient } from '@prisma/client';

let prismaInstance = null;

try {
  if (process.env.DATABASE_URL) {
    prismaInstance = new PrismaClient({
      log: process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
    });
  } else {
    console.warn('[Prisma] Notice: DATABASE_URL not set. Running in decoupled auth mode.');
  }
} catch (e) {
  console.warn('[Prisma Initialization Error]', e.message);
}

export const prisma = prismaInstance;

/**
 * Upsert Candidate User in PostgreSQL database
 */
export async function syncCandidateProfile({
  firebaseUid,
  email,
  fullName,
  photoUrl = null,
  isEmailVerified = true,
}) {
  if (!prisma) {
    return {
      synced: false,
      reason: 'DATABASE_URL_NOT_CONFIGURED',
      user: { firebaseUid, email, fullName, role: 'CANDIDATE' },
    };
  }

  try {
    const normalizedEmail = email ? email.trim().toLowerCase() : null;

    // 1. Check if user exists by firebaseUid or email
    let user = null;
    if (firebaseUid) {
      user = await prisma.user.findFirst({
        where: {
          OR: [
            { firebaseUid },
            ...(normalizedEmail ? [{ email: normalizedEmail }] : []),
          ],
        },
        include: { candidateProfile: true },
      });
    } else if (normalizedEmail) {
      user = await prisma.user.findUnique({
        where: { email: normalizedEmail },
        include: { candidateProfile: true },
      });
    }

    if (user) {
      // Update existing user
      user = await prisma.user.update({
        where: { id: user.id },
        data: {
          firebaseUid: firebaseUid || user.firebaseUid,
          isEmailVerified: isEmailVerified ?? user.isEmailVerified,
          lastLoginAt: new Date(),
        },
        include: { candidateProfile: true },
      });

      // Update Candidate Profile if fullName or photoUrl given
      if (fullName || photoUrl) {
        if (user.candidateProfile) {
          await prisma.candidateProfile.update({
            where: { id: user.candidateProfile.id },
            data: {
              fullName: fullName || user.candidateProfile.fullName,
              profilePhotoUrl: photoUrl || user.candidateProfile.profilePhotoUrl,
            },
          });
        } else if (fullName) {
          await prisma.candidateProfile.create({
            data: {
              userId: user.id,
              fullName,
              profilePhotoUrl: photoUrl,
            },
          });
        }
      }
    } else {
      // Create new User and CandidateProfile
      user = await prisma.user.create({
        data: {
          firebaseUid,
          email: normalizedEmail,
          role: 'CANDIDATE',
          status: 'ACTIVE',
          isEmailVerified,
          lastLoginAt: new Date(),
          candidateProfile: {
            create: {
              fullName: fullName || normalizedEmail?.split('@')[0] || 'Candidate',
              profilePhotoUrl: photoUrl,
            },
          },
        },
        include: { candidateProfile: true },
      });
    }

    return {
      synced: true,
      user: {
        id: user.id,
        firebaseUid: user.firebaseUid,
        email: user.email,
        role: user.role,
        fullName: user.candidateProfile?.fullName || fullName,
      },
    };
  } catch (err) {
    console.error('[syncCandidateProfile Error]', err.message);
    return {
      synced: false,
      error: err.message,
      user: { firebaseUid, email, fullName, role: 'CANDIDATE' },
    };
  }
}
