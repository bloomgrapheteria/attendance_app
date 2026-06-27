const express = require('express');
const cors = require('cors');
const { MongoClient, ObjectId } = require('mongodb');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 5050;
const JWT_SECRET = process.env.JWT_SECRET || 'bloomfield_jwt_secret_key_12345!';

// MongoDB Connection String
const MONGO_URI = process.env.MONGODB_URI || 'mongodb+srv://bloomfieldllp_db_user:zXeEFqe5U8cExf7z@cluster0.gh9jr5i.mongodb.net/attendance_db?retryWrites=true&w=majority&appName=Cluster0';
const DB_NAME = process.env.DB_NAME || 'attendance_db';

let db;

function hashPassword(password) {
  if (!password) return '';
  return crypto.createHash('sha256').update(password).digest('hex');
}

function ensureHashedPassword(data) {
  if (data && data.password && !/^[a-f0-9]{64}$/i.test(data.password)) {
    data.password = hashPassword(data.password);
  }
}

async function migrateExistingPasswords() {
  try {
    const usersColl = db.collection('users');
    const cursor = usersColl.find({});
    while (await cursor.hasNext()) {
      const user = await cursor.next();
      if (user.password && !/^[a-f0-9]{64}$/i.test(user.password)) {
        const hashed = hashPassword(user.password);
        await usersColl.updateOne({ _id: user._id }, { $set: { password: hashed } });
        console.log(`Migrated password for user: ${user.email}`);
      }
    }
  } catch (err) {
    console.error('Password migration error:', err);
  }
}

// Middleware to ensure DB connection is established (handles serverless/Vercel contexts cleanly)
let client;

async function ensureDbConnected() {
  if (db) return;
  if (!client) {
    console.log('Connecting to MongoDB Atlas...');
    client = new MongoClient(MONGO_URI);
    await client.connect();
    db = client.db(DB_NAME);
    console.log(`Connected to MongoDB database: ${DB_NAME}`);
    
    // Create/Verify indexes for optimal query speed
    try {
      await db.collection('users').createIndex({ email: 1 });
      await db.collection('users').createIndex({ schoolId: 1 });
      await db.collection('classes').createIndex({ schoolId: 1 });
      await db.collection('students').createIndex({ schoolId: 1 });
      await db.collection('students').createIndex({ classId: 1 });
      await db.collection('attendance').createIndex({ schoolId: 1, date: 1 });
      await db.collection('leave_requests').createIndex({ schoolId: 1 });
      console.log('Database indexes successfully verified/created.');
    } catch (idxErr) {
      console.error('Failed to create indexes:', idxErr);
    }

    // Migrate plain-text passwords to SHA-256 hashes
    await migrateExistingPasswords();
  }
}

app.use(async (req, res, next) => {
  try {
    await ensureDbConnected();
    next();
  } catch (err) {
    console.error('Database connection error:', err);
    res.status(500).json({ error: 'Internal Server Error: Database connection failed' });
  }
});

app.use(cors());
app.use(express.json());


// --- VALIDATION HELPER ---
async function validateDocument(collection, id, data, isUpdate = false) {
  let fullData = { ...data };
  if (isUpdate) {
    const existing = await db.collection(collection).findOne({ _id: id });
    if (existing) {
      fullData = { ...existing };
      if (data.$set) {
        fullData = { ...fullData, ...data.$set };
      }
      if (data.$unset) {
        for (const k of Object.keys(data.$unset)) {
          delete fullData[k];
        }
      }
    }
  }

  if (collection === 'users') {
    const usersColl = db.collection('users');
    
    // 1. Email uniqueness
    if (fullData.email) {
      const duplicate = await usersColl.findOne({ email: fullData.email, _id: { $ne: id } });
      if (duplicate) throw new Error('Email already registered');
    }
    
    // 2. Phone uniqueness
    if (fullData.phone) {
      const duplicate = await usersColl.findOne({ phone: fullData.phone, _id: { $ne: id } });
      if (duplicate) throw new Error('Phone number already exists');
    }
    
    // 3. Admin uniqueness per school
    if (fullData.role === 'admin' && fullData.schoolId) {
      const duplicate = await usersColl.findOne({ schoolId: fullData.schoolId, role: 'admin', _id: { $ne: id } });
      if (duplicate) throw new Error('This school already has an Admin');
    }
    
    // 4. Principal uniqueness per school
    if (fullData.role === 'principal' && fullData.schoolId) {
      const duplicate = await usersColl.findOne({ schoolId: fullData.schoolId, role: 'principal', _id: { $ne: id } });
      if (duplicate) throw new Error('This school already has a Principal');
    }
  }

  if (collection === 'classes') {
    const classesColl = db.collection('classes');
    if (fullData.name && fullData.schoolId) {
      const duplicate = await classesColl.findOne({ schoolId: fullData.schoolId, name: fullData.name, _id: { $ne: id } });
      if (duplicate) throw new Error('Class name already exists in this school');
    }
  }

  if (collection === 'students') {
    const studentsColl = db.collection('students');
    if (fullData.grNumber && fullData.schoolId) {
      const duplicate = await studentsColl.findOne({ schoolId: fullData.schoolId, grNumber: fullData.grNumber, _id: { $ne: id } });
      if (duplicate) throw new Error('Student with this GR number already exists in this school');
    }
  }
}

// --- AUTH APIs ---
app.post('/api/auth/register', async (req, res) => {
  const { email, password, customUid, role, schoolId } = req.body;
  try {
    const usersColl = db.collection('users');
    const existing = await usersColl.findOne({ email });
    if (existing) return res.status(400).json({ error: 'Email already registered' });

    const uid = customUid || new ObjectId().toString();
    const existingUid = await usersColl.findOne({ _id: uid });
    if (existingUid) return res.status(400).json({ error: 'User ID already exists' });

    const userRole = role || 'admin';

    // Validate school limits if schoolId is provided at signup
    if (schoolId) {
      if (userRole === 'admin') {
        const existingAdmin = await usersColl.findOne({ schoolId, role: 'admin' });
        if (existingAdmin) return res.status(400).json({ error: 'This school already has an Admin' });
      }
      if (userRole === 'principal') {
        const existingPrincipal = await usersColl.findOne({ schoolId, role: 'principal' });
        if (existingPrincipal) return res.status(400).json({ error: 'This school already has a Principal' });
      }
    }

    await usersColl.insertOne({
      _id: uid,
      email,
      password: hashPassword(password),
      role: userRole,
      schoolId: schoolId || null,
      createdAt: new Date()
    });

    const token = jwt.sign({ sub: uid, role: userRole }, JWT_SECRET, { expiresIn: '7d' });
    res.json({ token, uid });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const usersColl = db.collection('users');
    const user = await usersColl.findOne({ email });
    if (!user) return res.status(400).json({ error: 'User not found' });
    if (user.password !== hashPassword(password)) return res.status(400).json({ error: 'Wrong password' });

    const token = jwt.sign({ sub: user._id, role: user.role || 'teacher' }, JWT_SECRET, { expiresIn: '7d' });
    res.json({ token, uid: user._id, user });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/bulk/students', async (req, res) => {
  const { students, action, schoolId } = req.body;
  if (!Array.isArray(students) || !students.length) {
    return res.status(400).json({ error: 'No students provided' });
  }

  try {
    const studentsColl = db.collection('students');
    const classesColl = db.collection('classes');

    // 1. Get existing students for this school to check duplicate GRs
    const query = { schoolId };
    const existingStudents = await studentsColl.find(query).toArray();
    const existingGRs = new Set(existingStudents.map(s => s._id));

    // 2. Fetch existing classes to prevent duplicate class creations
    const existingClasses = await classesColl.find({ schoolId }).toArray();
    const existingClassesMap = new Map();
    for (const c of existingClasses) {
      const canonical = c._id.toUpperCase().replace(/[^A-Z0-9]/g, '');
      existingClassesMap.set(canonical, c._id);
    }

    let success = 0;
    let skipped = 0;
    const errors = [];
    const bulkOps = [];
    const classOps = [];

    // Temporary map for classes created in this run to avoid duplicate creations
    const createdClasses = new Set();

    for (const student of students) {
      // Ensure schoolId is present in student record
      student.schoolId = schoolId;

      // Extract GR number as the primary key
      const gr = student.grNumber;
      if (!gr) {
        skipped++;
        errors.push(`Missing GR number for student: ${student.name || 'Unknown'}`);
        continue;
      }

      // Map classId
      const classId = student.classId;
      if (classId) {
        const normalized = classId.trim();
        const canonical = normalized.toUpperCase().replace(/[^A-Z0-9]/g, '');

        let targetClassDocId = normalized;
        if (existingClassesMap.has(canonical)) {
          targetClassDocId = existingClassesMap.get(canonical);
        } else if (!createdClasses.has(canonical)) {
          // Setup class creation
          classOps.push({
            updateOne: {
              filter: { _id: `${schoolId}_${normalized}` },
              update: {
                $setOnInsert: {
                  _id: `${schoolId}_${normalized}`,
                  name: normalized,
                  schoolId,
                  totalStudents: 0,
                  boys: 0,
                  girls: 0,
                  updatedAt: new Date()
                }
              },
              upsert: true
            }
          });
          createdClasses.add(canonical);
          existingClassesMap.set(canonical, `${schoolId}_${normalized}`);
          targetClassDocId = `${schoolId}_${normalized}`;
        } else {
          targetClassDocId = `${schoolId}_${normalized}`;
        }
        student.classId = targetClassDocId;
      }

      // Format date fields
      if (student.createdAt && typeof student.createdAt === 'string') student.createdAt = new Date(student.createdAt);
      else student.createdAt = new Date();
      if (student.dob && typeof student.dob === 'string') student.dob = new Date(student.dob);

      // Resolve duplicate GR action
      const exists = existingGRs.has(`${schoolId}_${gr}`);
      const resolvedId = `${schoolId}_${gr}`;

      student._id = resolvedId;

      if (exists) {
        if (action === 'skip') {
          skipped++;
          errors.push(`Skipped duplicate GR: ${gr}`);
          continue;
        }
        if (action === 'overwrite') {
          bulkOps.push({
            replaceOne: {
              filter: { _id: resolvedId },
              replacement: student,
              upsert: true
            }
          });
          success++;
        }
      } else {
        bulkOps.push({
          insertOne: {
            document: student
          }
        });
        success++;
      }
    }

    // Run class operations first if any
    if (classOps.length) {
      await classesColl.bulkWrite(classOps);
    }

    // Run student bulk operations
    if (bulkOps.length) {
      await studentsColl.bulkWrite(bulkOps);
    }

    // 4. Recalculate Class Counts (boys, girls, total) in MongoDB
    const pipeline = [
      { $match: { schoolId } },
      {
        $group: {
          _id: '$classId',
          total: { $sum: 1 },
          boys: {
            $sum: {
              $cond: [
                { $in: ['$gender', ['male', 'boy', 'm']] },
                1,
                0
              ]
            }
          },
          girls: {
            $sum: {
              $cond: [
                { $in: ['$gender', ['female', 'girl', 'f']] },
                1,
                0
              ]
            }
          }
        }
      }
    ];

    const counts = await studentsColl.aggregate(pipeline).toArray();
    const classCountUpdates = counts
      .filter(c => c._id) // ignore empty classId
      .map(c => ({
        updateOne: {
          filter: { _id: c._id },
          update: {
            $set: {
              totalStudents: c.total,
              boys: c.boys,
              girls: c.girls,
              updatedAt: new Date()
            }
          }
        }
      }));

    if (classCountUpdates.length) {
      await classesColl.bulkWrite(classCountUpdates);
    }

    res.json({ success: true, successCount: success, skippedCount: skipped, errors });
  } catch (err) {
    console.error('Bulk import error:', err);
    res.status(500).json({ error: err.message });
  }
});

// --- GENERIC REST CRUD APIs ---
app.get('/api/documents/:collection', async (req, res) => {
  const { collection } = req.params;
  const filters = req.query.filters ? JSON.parse(req.query.filters) : {};
  const limit = req.query.limit ? parseInt(req.query.limit) : 0;
  const sort = req.query.sort ? JSON.parse(req.query.sort) : null;

  try {
    const coll = db.collection(collection);
    let query = coll.find(filters);
    if (sort) query = query.sort(sort);
    if (limit > 0) query = query.limit(limit);
    const docs = await query.toArray();
    res.json(docs);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/documents/:collection/:id', async (req, res) => {
  const { collection, id } = req.params;
  try {
    const coll = db.collection(collection);
    const doc = await coll.findOne({ _id: id });
    res.json(doc);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/documents/:collection/:id', async (req, res) => {
  const { collection, id } = req.params;
  const data = req.body;
  try {
    await validateDocument(collection, id, data, false);

    const coll = db.collection(collection);

    // Preserve the password field if it already exists and is not provided in this payload
    if (collection === 'users' && !data.password) {
      const existingUser = await coll.findOne({ _id: id });
      if (existingUser && existingUser.password) {
        data.password = existingUser.password;
      }
    }

    if (collection === 'users') {
      ensureHashedPassword(data);
    }

    data._id = id;
    if (data.createdAt && typeof data.createdAt === 'string') data.createdAt = new Date(data.createdAt);
    if (data.dob && typeof data.dob === 'string') data.dob = new Date(data.dob);
    
    await coll.replaceOne({ _id: id }, data, { upsert: true });
    res.json({ success: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.put('/api/documents/:collection/:id', async (req, res) => {
  const { collection, id } = req.params;
  const updatePayload = req.body;
  try {
    await validateDocument(collection, id, updatePayload, true);

    const coll = db.collection(collection);
    const finalUpdate = {};
    if (updatePayload.$set) {
      const $set = { ...updatePayload.$set };
      if ($set.createdAt && typeof $set.createdAt === 'string') $set.createdAt = new Date($set.createdAt);
      if ($set.dob && typeof $set.dob === 'string') $set.dob = new Date($set.dob);
      if (collection === 'users') {
        ensureHashedPassword($set);
      }
      finalUpdate.$set = $set;
    }
    if (updatePayload.$unset) {
      finalUpdate.$unset = updatePayload.$unset;
    }
    await coll.updateOne({ _id: id }, finalUpdate);
    res.json({ success: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.delete('/api/documents/:collection/:id', async (req, res) => {
  const { collection, id } = req.params;
  try {
    const coll = db.collection(collection);
    await coll.deleteOne({ _id: id });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Start server locally if run directly, otherwise export for Vercel Serverless Functions
if (require.main === module) {
  ensureDbConnected()
    .then(() => {
      app.listen(PORT, () => {
        console.log(`API Server running on port ${PORT}`);
      });
    })
    .catch(err => {
      console.error('Failed to initialize server:', err);
      process.exit(1);
    });
}

module.exports = app;

