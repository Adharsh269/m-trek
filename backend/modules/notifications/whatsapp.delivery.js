
import { createClient } from "@supabase/supabase-js";
import { sendWhatsAppMessage } from "./whatsapp.service.js";

let db;

function getAdminClient() {
  if (!db) {
    const url = process.env.SUPABASE_URL;
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!url || !key) {
      throw new Error("Missing Supabase credentials");
    }

    db = createClient(url, key, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });
  }

  return db;
}

export async function deliverDueWhatsAppNotifications() {
  const afterId = Number(process.env.WHATSAPP_DELIVERY_AFTER_ID);

  if (!Number.isSafeInteger(afterId) || afterId < 0) {
    throw new Error("Invalid WHATSAPP_DELIVERY_AFTER_ID");
  }

  const db = getAdminClient();

  const { data: notifications, error } = await db.rpc(
    "claim_due_whatsapp_notifications",
    {
      p_after_id: afterId,
      p_limit: 5,
    }
  );

  if (error) throw error;

  let sent = 0;
  let failed = 0;

  for (const notification of notifications ?? []) {
    try {
      const { data: recipients, error: recipientsError } =
        await db
          .from("notification_recipients")
          .select(`
            id,
            status,
            family_contact_id,
            patient_family_contacts (
              phone,
              active,
              whatsapp_enabled
            )
          `)
          .eq("notification_id", notification.id)
          .not("family_contact_id", "is", null);

      if (recipientsError) throw recipientsError;

      let attempted = 0;
      let successes = 0;

      for (const recipient of recipients ?? []) {
        if (recipient.status !== "pending") continue;

        const contact = recipient.patient_family_contacts;

        if (
          !contact?.active ||
          !contact.whatsapp_enabled ||
          !contact.phone
        ) {
          continue;
        }

        attempted++;

        try {
          const result = await sendWhatsAppMessage({
            to: contact.phone,
            variables: {},
          });

          // Twilio accepted the message request.
          const { error: updateError } = await db
            .from("notification_recipients")
            .update({
              status: "sent",
              sent_at: new Date().toISOString(),
            })
            .eq("id", recipient.id)
            .eq("status", "pending");

          if (updateError) throw updateError;

          successes++;

          console.log(
            `[WhatsApp] Notification ${notification.id}: accepted by Twilio (${result.sid})`
          );
        } catch (sendError) {
          console.error(
            `[WhatsApp] Recipient ${recipient.id}:`,
            sendError.message
          );

          // Don't automatically retry uncertain Twilio outcomes.
          const { error: failError } = await db
            .from("notification_recipients")
            .update({ status: "failed" })
            .eq("id", recipient.id)
            .eq("status", "pending");

          if (failError) {
            console.error("[WhatsApp] Status update:", failError.message);
          }
        }
      }

      const status =
        attempted > 0 && attempted === successes
          ? "sent"
          : "failed";

      const update = { status };

      if (status === "sent") {
        update.sent_at = new Date().toISOString();
      }

      const { error: updateError } = await db
        .from("notifications")
        .update(update)
        .eq("id", notification.id)
        .eq("status", "processing");

      if (updateError) throw updateError;

      if (status === "sent") sent++;
      else failed++;
    } catch (error) {
      console.error(
        `[WhatsApp] Notification ${notification.id}:`,
        error.message
      );

      // Leave uncertain jobs in processing for manual review.
      failed++;
    }
  }

  return { sent, failed };
}
