import "dotenv/config";
import { sendWhatsAppMessage } from "./modules/notifications/whatsapp.service.js";

async function main() {
  if (process.env.WHATSAPP_TEST_MODE !== "true") {
    throw new Error("WhatsApp test mode is disabled");
  }

  const phone = process.env.TEST_WHATSAPP_PHONE;

  if (!phone || !/^\+[1-9]\d{7,14}$/.test(phone)) {
    throw new Error("Set a valid TEST_WHATSAPP_PHONE");
  }

  const result = await sendWhatsAppMessage({
    to: phone,
    variables: {},
  });

  console.log("WhatsApp test result:", result);
}

main().catch((error) => {
  console.error("WhatsApp test failed:", error.message);
  process.exitCode = 1;
});