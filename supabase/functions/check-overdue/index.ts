/**
 * Supabase Edge Function: check-overdue
 * 
 * Deployment:
 * 1. supabase link --project-ref nvjzyblxtusioknixlff
 * 2. supabase secrets set TWILIO_ACCOUNT_SID=xxx TWILIO_AUTH_TOKEN=xxx TWILIO_PHONE_NUMBER=xxx
 * 3. supabase functions deploy check-overdue
 * 4. Set up pg_cron in Supabase Dashboard to call hourly
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface UserSettings {
  user_id: string
  check_in_interval_hours: number
  alert_message: string
  last_check_in: string | null
  alert_sent: boolean
}

interface Profile {
  id: string
  full_name: string | null
  email: string
}

interface EmergencyContact {
  id: string
  user_id: string
  name: string
  phone_number: string
  priority: number
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const twilioAccountSid = Deno.env.get('TWILIO_ACCOUNT_SID')
    const twilioAuthToken = Deno.env.get('TWILIO_AUTH_TOKEN')
    const twilioPhoneNumber = Deno.env.get('TWILIO_PHONE_NUMBER')
    const twilioEnabled = twilioAccountSid && twilioAuthToken && twilioPhoneNumber

    console.log(`[check-overdue] Starting at ${new Date().toISOString()}, Twilio: ${twilioEnabled}`)

    const now = new Date()
    
    const { data: usersToCheck, error: queryError } = await supabase
      .from('user_settings')
      .select('*')
      .eq('alert_sent', false)
      .not('last_check_in', 'is', null)

    if (queryError) {
      throw new Error(`Query failed: ${queryError.message}`)
    }

    const overdueUsers = (usersToCheck || []).filter((user: UserSettings) => {
      if (!user.last_check_in) return false
      const lastCheckIn = new Date(user.last_check_in)
      const deadline = new Date(lastCheckIn.getTime() + user.check_in_interval_hours * 60 * 60 * 1000)
      return now > deadline
    })

    console.log(`[check-overdue] ${overdueUsers.length}/${usersToCheck?.length || 0} users overdue`)

    const results: Array<{ userId: string; status: string; contactsNotified: number }> = []

    for (const user of overdueUsers) {
      try {
        const { data: profile } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', user.user_id)
          .single()

        const { data: contacts } = await supabase
          .from('emergency_contacts')
          .select('*')
          .eq('user_id', user.user_id)
          .order('priority', { ascending: true })

        if (!contacts || contacts.length === 0) {
          results.push({ userId: user.user_id, status: 'skipped_no_contacts', contactsNotified: 0 })
          continue
        }

        const userName = profile?.full_name || profile?.email || 'A user'
        const message = user.alert_message
          .replace('{user_name}', userName)
          .replace('{interval}', String(user.check_in_interval_hours))

        let notifiedCount = 0
        for (const contact of contacts) {
          try {
            if (twilioEnabled) {
              await sendTwilioSMS(twilioAccountSid!, twilioAuthToken!, twilioPhoneNumber!, contact.phone_number, message)
            }
            console.log(`[check-overdue] ${twilioEnabled ? 'Sent' : '[MOCK]'} SMS to ${contact.name}`)
            notifiedCount++
          } catch (smsError) {
            console.error(`[check-overdue] SMS failed for ${contact.phone_number}:`, smsError)
          }
        }

        await supabase
          .from('user_settings')
          .update({ alert_sent: true })
          .eq('user_id', user.user_id)

        results.push({ userId: user.user_id, status: 'alerted', contactsNotified: notifiedCount })

      } catch (userError) {
        console.error(`[check-overdue] Error for ${user.user_id}:`, userError)
        results.push({ userId: user.user_id, status: 'error', contactsNotified: 0 })
      }
    }

    return new Response(
      JSON.stringify({ success: true, timestamp: now.toISOString(), usersOverdue: overdueUsers.length, results }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('[check-overdue] Error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

async function sendTwilioSMS(accountSid: string, authToken: string, from: string, to: string, body: string): Promise<void> {
  const response = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${btoa(`${accountSid}:${authToken}`)}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({ To: to, From: from, Body: body }),
  })

  if (!response.ok) {
    throw new Error(`Twilio error: ${response.status} - ${await response.text()}`)
  }
}
