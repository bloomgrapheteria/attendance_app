const { MongoClient } = require('mongodb');

const MONGO_URI = 'mongodb+srv://bloomfieldllp_db_user:zXeEFqe5U8cExf7z@cluster0.gh9jr5i.mongodb.net/attendance_db?retryWrites=true&w=majority&appName=Cluster0';
const DB_NAME = 'attendance_db';

async function run() {
  const client = new MongoClient(MONGO_URI);
  try {
    await client.connect();
    const db = client.db(DB_NAME);
    
    const classes = await db.collection('classes').find({}).toArray();
    console.log("All Classes:");
    for (const c of classes) {
      console.log(`- ID: ${c._id}, Name: ${c.name}, teacher: ${c.teacher || c.classTeacher || c.classTeacherName || c.classTeacherId || 'none'}`);
    }
  } catch (err) {
    console.error(err);
  } finally {
    await client.close();
  }
}
run();
