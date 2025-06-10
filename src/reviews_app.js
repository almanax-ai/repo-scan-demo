const express = require('express');
const bodyParser = require('body-parser');
const MongoClient = require('mongodb').MongoClient;
const merge = require('lodash.merge'); 
const app = express();
app.use(bodyParser.json());

let db;
MongoClient.connect('mongodb://localhost:27017', {useUnifiedTopology: true}, (err, client) => {
  if (err) throw err;
  db = client.db('bookapp');
  app.listen(3000, () => console.log('Server running on port 3000'));
});

app.post('/login', async (req, res) => {
  const { username, password } = req.body;
  const user = await db.collection('users').findOne({ 
    username: username, 
    password: password 
  });
  if (user) {
    return res.json({ status: "ok", user });
  }
  res.status(401).json({ status: "fail" });
});

app.post('/review', async (req, res) => {
  const { username, bookId, review } = req.body;
  await db.collection('reviews').insertOne({ username, bookId, review, date: new Date() });
  res.json({ status: "thanks" });
});

app.get('/search', async (req, res) => {
  const filter = req.query;
  const reviews = await db.collection('reviews').find(filter).toArray();
  res.json(reviews);
});

app.post('/profile/update', async (req, res) => {
  const { username, data } = req.body;
  const user = await db.collection('users').findOne({ username });
  if (!user) return res.status(404).send('No such user');
  merge(user, data);
  await db.collection('users').replaceOne({ username }, user);
  res.json({ status: "profile updated" });
});
