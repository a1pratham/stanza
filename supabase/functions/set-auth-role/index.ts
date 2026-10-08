// Stanza -- set-auth-role Edge Function.
//
// Purpose: assigns the `role: 'authenticated'` custom claim to a Firebase
// user, immediately after Firebase sign-up or sign-in. This is required
// because Firebase ID tokens carry no `role` claim by default, and
// without one, Supabase's Postgres layer treats every request as
// Postgres role `anon` -- meaning every RLS policy scoped `to
// authenticated` (0010_firebase_identity.sql) would silently never match,
// for anyone.
//
// IMPORTANT -- what this function does NOT do:
//   - Does not create a Supabase Auth user.
//   - Does not create a Supabase session.
//   - Does not touch auth.users or any Supabase table at all.
//   - Does not use the Supabase service-role key (this function needs no
//     Supabase client whatsoever).
// It talks to exactly one system: the Firebase Admin API, to set one
// custom claim on one Firebase user. Firebase remains the sole identity
// provider.
//
// Security note: the caller sends their own Firebase ID token, but this
// function does NOT trust a client-supplied UID. It independently
// verifies the token's signature via the Firebase Admin SDK
// (verifyIdToken), which confirms the token is genuinely issued by your
// Firebase project and not expired/tampered -- only the UID extracted
// from that verification is ever used.

import { initializeApp, cert, getApps } from 'npm:firebase-admin@12/app';
import { getAuth } from 'npm:firebase-admin@12/auth';

const SERVICE_ACCOUNT_JSON = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');

if (!SERVICE_ACCOUNT_JSON) {
  console.error('FIREBASE_SERVICE_ACCOUNT_JSON is not set.');
}

// Initialize once per function instance, not per request -- Deno Edge
// Functions reuse warm instances across invocations, and re-initializing
// the Firebase Admin app on every request would be wasteful and can
// throw ("app already exists") on a warm instance.
if (!getApps().length && SERVICE_ACCOUNT_JSON) {
  const serviceAccount = JSON.parse(SERVICE_ACCOUNT_JSON);
  initializeApp({ credential: cert(serviceAccount) });
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ ok: false, error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const authHeader = req.headers.get('Authorization');
  const idToken = authHeader?.replace(/^Bearer\s+/i, '');

  if (!idToken) {
    return new Response(
      JSON.stringify({ ok: false, error: 'Missing Firebase ID token in Authorization header.' }),
      { status: 401, headers: { 'Content-Type': 'application/json' } },
    );
  }

  try {
    // Verifies signature, expiry, issuer and audience against this
    // function's own Firebase project credentials. Throws if the token
    // is invalid, expired, or from a different Firebase project -- in
    // any of those cases we never reach the UID we'd otherwise trust.
    const decoded = await getAuth().verifyIdToken(idToken);
    const uid = decoded.uid;

    // Merge rather than overwrite: setCustomUserClaims() replaces the
    // ENTIRE custom claims object, not just the fields you pass. No other
    // custom claims exist today, but reading the current ones first means
    // adding another claim later won't silently clobber this one (or
    // vice versa).
    const existingUser = await getAuth().getUser(uid);
    const existingClaims = existingUser.customClaims ?? {};

    if (existingClaims.role === 'authenticated') {
      // Already set on a previous call (e.g. a repeat sign-in) --
      // nothing to do. Avoids an unnecessary write.
      return new Response(JSON.stringify({ ok: true, alreadySet: true }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    await getAuth().setCustomUserClaims(uid, {
      ...existingClaims,
      role: 'authenticated',
    });

    console.log(`Set role:authenticated claim for Firebase UID ${uid}`);

    return new Response(JSON.stringify({ ok: true, alreadySet: false }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('set-auth-role failed:', err.message);
    return new Response(JSON.stringify({ ok: false, error: 'Invalid or expired token.' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
