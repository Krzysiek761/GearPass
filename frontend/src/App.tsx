import { useState, useEffect } from 'react';
import './App.css';
import mockData from './mockData.json';

interface Equipment {
  id: number;
  name: string;
  category: string;
  status: string;
}

function App() {
  // Stan przechowujący nasze dane - gotowy na podpięcie backendu
  const [equipment, setEquipment] = useState<Equipment[]>([]);

  // useEffect symuluje moment pobierania danych po załadowaniu strony
  useEffect(() => {
    setEquipment(mockData);
  }, []);

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
          {equipment.map((item) => (
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
  );
}

export default App;