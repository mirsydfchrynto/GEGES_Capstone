const admin = require('firebase-admin');
const axios = require('axios');

// Inisialisasi Firebase Admin
// Pastikan Anda sudah menjalankan 'firebase login' atau set GOOGLE_APPLICATION_CREDENTIALS
try {
  admin.initializeApp({
    projectId: 'geges-smartbarber-project' // Project ID Anda
  });
} catch (e) {
  console.error("Gagal inisialisasi Firebase. Pastikan Anda login dengan `gcloud auth application-default login` atau `firebase login:ci`.");
  process.exit(1);
}

const db = admin.firestore();
const SENTIMENT_API_URL = 'https://mirsydfchyrnto-review-api.hf.space/predict';

const reviewsToSeed = [
  {
    text: 'Pelayanan sangat memuaskan, potongannya rapi dan barbernya ramah banget!',
    stars: 5.0,
    shopId: 'geges-shop-1',
    shopName: 'Geges Barber Slawi',
    expected: 'positif'
  },
  {
    text: 'Tempatnya panas, antrian lama, hasil cukurnya tidak rata. Kecewa.',
    stars: 1.0,
    shopId: 'febrian-shop-2',
    shopName: 'Febrian Barbershop',
    expected: 'negatif'
  },
  {
    text: 'Lumayan lah, standar aja seperti barbershop biasa.',
    stars: 3.0,
    shopId: 'geges-shop-1',
    shopName: 'Geges Barber Slawi',
    expected: 'netral'
  },
  {
    text: 'Gokil, hasilnya keren parah! Next bakal langganan di sini.',
    stars: 5.0,
    shopId: 'andi-shop-3',
    shopName: 'Andi Premium Cut',
    expected: 'positif'
  },
  {
    text: 'Mahal doang tapi kualitas nol. Gak recommended.',
    stars: 2.0,
    shopId: 'febrian-shop-2',
    shopName: 'Febrian Barbershop',
    expected: 'negatif'
  }
];

async function analyzeAndSave(review) {
  console.log(`\n📝 Processing: "${review.text.substring(0, 30)}"...`);
  
  try {
    // 1. Call API
    const response = await axios.post(SENTIMENT_API_URL, {
      review: review.text
    });
    
    const { prediction, confidence } = response.data;
    console.log(`   🤖 API Result: ${prediction} (${(confidence * 100).toFixed(1)}%)`);

    // 2. Filter & Save
    if (prediction === 'positif' || prediction === 'negatif') {
      const docData = {
        userId: 'seeder_node_user',
        userName: 'Node Seeder',
        userEmail: 'seeder@node.com',
        rating: review.stars,
        feedback: review.text,
        platform: 'node_script',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        processed: true,
        sentiment: prediction,
        sentimentConfidence: confidence,
        barbershopId: review.shopId,
        barbershopName: review.shopName
      };

      await db.collection('app_ratings').add(docData);
      console.log(`   ✅ SAVED to Firestore!`);
    } else {
      console.log(`   ⚠️ SKIPPED (Sentiment: ${prediction})`);
    }

  } catch (error) {
    console.error(`   ❌ Error: ${error.message}`);
    if (error.response) console.error("   API Response:", error.response.data);
  }
}

async function run() {
  console.log("🚀 Starting Node.js Rating Seeder...");
  for (const review of reviewsToSeed) {
    await analyzeAndSave(review);
    // Delay sedikit agar tidak spam API
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  console.log("\n✅ Done.");
}

run();
