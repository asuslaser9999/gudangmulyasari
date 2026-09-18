import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const INTERNAL_DOMAIN = '@gudangmulyasari.pos'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function normalizeUsername(raw: string): string {
  return raw.trim().toLowerCase()
}

function validateUsername(username: string): string | null {
  if (username.length < 3) return 'Username minimal 3 karakter'
  if (username.length > 32) return 'Username maksimal 32 karakter'
  if (!/^[a-z0-9_]+$/.test(username)) {
    return 'Username hanya huruf kecil, angka, dan underscore'
  }
  return null
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return json({ error: 'Unauthorized' }, 401)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    })

    const {
      data: { user: caller },
      error: callerError,
    } = await userClient.auth.getUser()

    if (callerError || !caller) {
      return json({ error: 'Unauthorized' }, 401)
    }

    const { data: allowed, error: permError } = await userClient.rpc(
      'gm_has_permission',
      { p_code: 'users.manage' },
    )
    if (permError || allowed !== true) {
      return json({ error: 'Tidak punya hak kelola user Gudang Mulyasari' }, 403)
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey)
    const body = await req.json()
    const action = body.action as string

    if (action === 'create') {
      const displayName = (body.display_name as string)?.trim() ?? ''
      const username = normalizeUsername(body.username ?? '')
      const password = body.password as string
      const roleId = body.role_id as string
      const locationIds = (body.location_ids as string[] | undefined) ?? []

      if (!displayName) {
        return json({ error: 'Nama wajib diisi' }, 400)
      }

      const usernameError = validateUsername(username)
      if (usernameError) {
        return json({ error: usernameError }, 400)
      }

      if (!password || password.length < 6) {
        return json({ error: 'Password minimal 6 karakter' }, 400)
      }

      if (!roleId) {
        return json({ error: 'Role wajib dipilih' }, 400)
      }

      const { data: existing } = await adminClient
        .from('gm_profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle()

      if (existing) {
        return json({ error: 'Username sudah digunakan di Gudang Mulyasari' }, 400)
      }

      const { data: roleRow } = await adminClient
        .from('gm_roles')
        .select('code')
        .eq('id', roleId)
        .single()

      const email = `${username}${INTERNAL_DOMAIN}`

      const { data, error } = await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          gm_role_id: roleId,
          gm_role_code: roleRow?.code ?? 'staff',
          gm_username: username,
          display_name: displayName,
        },
      })

      if (error) {
        return json({ error: error.message }, 400)
      }

      await adminClient
        .from('gm_profiles')
        .update({
          display_name: displayName,
          username,
          role_id: roleId,
          is_active: true,
          email,
        })
        .eq('id', data.user.id)

      if (locationIds.length > 0) {
        await adminClient.from('gm_user_location_access').insert(
          locationIds.map((locationId) => ({
            user_id: data.user.id,
            location_id: locationId,
          })),
        )
      }

      return json({ user_id: data.user.id })
    }

    if (action === 'update') {
      const userId = body.user_id as string
      const displayName = body.display_name as string | undefined
      const roleId = body.role_id as string | undefined
      const isActive = body.is_active as boolean | undefined
      const password = body.password as string | undefined
      const locationIds = body.location_ids as string[] | undefined

      if (!userId) {
        return json({ error: 'User tidak ditemukan' }, 400)
      }

      if (userId === caller.id && isActive === false) {
        return json({ error: 'Tidak bisa menonaktifkan akun sendiri' }, 400)
      }

      const profileUpdates: Record<string, unknown> = {}
      if (displayName !== undefined) {
        profileUpdates.display_name = displayName.trim()
      }
      if (roleId !== undefined) {
        profileUpdates.role_id = roleId
      }
      if (isActive !== undefined) {
        profileUpdates.is_active = isActive
      }

      if (Object.keys(profileUpdates).length > 0) {
        const { error } = await adminClient
          .from('gm_profiles')
          .update(profileUpdates)
          .eq('id', userId)

        if (error) {
          return json({ error: error.message }, 400)
        }
      }

      if (locationIds !== undefined) {
        await adminClient
          .from('gm_user_location_access')
          .delete()
          .eq('user_id', userId)
        if (locationIds.length > 0) {
          await adminClient.from('gm_user_location_access').insert(
            locationIds.map((locationId) => ({
              user_id: userId,
              location_id: locationId,
            })),
          )
        }
      }

      const authUpdates: {
        password?: string
        ban_duration?: string
      } = {}

      if (password != null && password.length > 0) {
        if (password.length < 6) {
          return json({ error: 'Password minimal 6 karakter' }, 400)
        }
        authUpdates.password = password
      }

      if (isActive === false) {
        authUpdates.ban_duration = '876000h'
      } else if (isActive === true) {
        authUpdates.ban_duration = 'none'
      }

      if (Object.keys(authUpdates).length > 0) {
        const { error } = await adminClient.auth.admin.updateUserById(
          userId,
          authUpdates,
        )
        if (error) {
          return json({ error: error.message }, 400)
        }
      }

      return json({ ok: true })
    }

    return json({ error: 'Aksi tidak dikenali' }, 400)
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Terjadi kesalahan'
    return json({ error: message }, 500)
  }
})
