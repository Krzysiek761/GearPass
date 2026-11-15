import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import './App.css';
import mockData from './mockData.json';

interface Equipment {
  id: number;
  name: string;
  category: string;
  status: string;
}

async function loadEquipment(): Promise<Equipment[]> {
  const response = await fetch('/api/equipment');
  if (!response.ok) throw new Error('Nie udało się pobrać katalogu.');
  return response.json();
}

function App() {
  const [equipment, setEquipment] = useState<Equipment[]>(mockData);
  const [persistent, setPersistent] = useState(false);
  const [message, setMessage] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const controller = new AbortController();
    async function load() {
      try {
        const response = await fetch('/api/health', { signal: controller.signal });
        if (!response.ok) {
          const detail = await response.json();
          if (detail.detail === 'Baza danych jest niedostępna') {
            setEquipment([]);
            setMessage(detail.detail);
          }
          return;
        }
        const health = await response.json();
        if (health.storage === 'postgresql') {
          setPersistent(true);
          setEquipment(await loadEquipment());
        }
      } catch (error) {
        if (!controller.signal.aborted) setMessage((error as Error).message);
      }
    }
    void load();
    return () => controller.abort();
  }, []);

  async function addEquipment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    const values = new FormData(form);
    setSaving(true);
    setMessage('');
    try {
      const response = await fetch('/api/equipment', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-GearPass-Key': String(values.get('key')),
        },
        body: JSON.stringify({
          name: values.get('name'),
          category: values.get('category'),
        }),
      });
      if (response.status === 403) throw new Error('Podaj prawidłowy klucz zapisu.');
      if (!response.ok) throw new Error('Nie udało się zapisać sprzętu.');
      setEquipment(await loadEquipment());
      setMessage('Sprzęt został zapisany.');
      form.reset();
    } catch (error) {
      setMessage((error as Error).message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div style={{ padding: '20px', fontFamily: 'sans-serif' }}>
      <h1>Katalog Sprzętu - GearPass</h1>
      <table border={1} cellPadding={10} style={{ borderCollapse: 'collapse', width: '100%', textAlign: 'left' }}>
        <thead>
          <tr style={{ backgroundColor: '#f0f0f0', color: '#242424' }}>
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
              <td style={{ color: item.status === 'Dostępny' ? '#3b9e56' : '#df4e55', fontWeight: 'bold' }}>
                {item.status}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {persistent && (
        <form onSubmit={addEquipment} style={{ display: 'flex', flexWrap: 'wrap', gap: '12px', marginTop: '20px' }}>
          <label>Nazwa sprzętu <input name="name" minLength={2} required /></label>
          <label>Kategoria <input name="category" required /></label>
          <label>Klucz zapisu <input name="key" type="password" autoComplete="off" required /></label>
          <button disabled={saving} type="submit">{saving ? 'Zapisuję…' : 'Dodaj sprzęt'}</button>
        </form>
      )}
      {message && <p role="status">{message}</p>}
    </div>
  );
}

export default App;
