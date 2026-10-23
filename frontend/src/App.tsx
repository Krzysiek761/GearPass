import './App.css'

// Dane makietowe (Mock Data) dla aplikacji GearPass
const mockEquipment = [
  { id: 1, name: 'Aparat Sony A7 III', category: 'Foto', status: 'Dostępny' },
  { id: 2, name: 'Gogle Meta Quest 3', category: 'VR', status: 'Wypożyczony' },
  { id: 3, name: 'Mikrofon Rode NT1-A', category: 'Audio', status: 'Dostępny' },
  { id: 4, name: 'Konsola PlayStation 5', category: 'Gaming', status: 'Dostępny' }
];

function App() {
  return (
    <div style={{ padding: '20px', fontFamily: 'sans-serif' }}>
      <h1>Katalog Sprzętu - GearPass</h1>
      <table border={1} cellPadding={10} style={{ borderCollapse: 'collapse', width: '100%', textAlign: 'left' }}>
        <thead>
          <tr style={{ backgroundColor: '#f0f0f0' }}>
            <th>ID</th>
            <th>Nazwa sprzętu</th>
            <th>Kategoria</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {mockEquipment.map((item) => (
            <tr key={item.id}>
              <td>{item.id}</td>
              <td>{item.name}</td>
              <td>{item.category}</td>
              <td style={{ color: item.status === 'Dostępny' ? 'green' : 'red', fontWeight: 'bold' }}>
                {item.status}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export default App