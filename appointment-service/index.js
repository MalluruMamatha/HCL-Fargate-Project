// Import the Express library
const express = require('express');

// Create an instance of Express
const app = express();

// Middleware to parse JSON bodies
app.use(express.json());

// Sample route to test if the server is running
app.get('/', (req, res) => {
  res.send('Hello from Appointment Service!');
});

// Sample API route to handle appointments (for example purposes)
app.post('/appointments', (req, res) => {
  const { name, date, time } = req.body;
  if (!name || !date || !time) {
    return res.status(400).json({ error: 'Missing required fields: name, date, time' });
  }
  // For now, just returning a success message with the data
  res.status(201).json({
    message: 'Appointment created successfully',
    appointment: { name, date, time }
  });
});

// Define the port number
const PORT = process.env.PORT || 3001;

// Start the server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
