import { useState } from 'react'
import { useLocation, Link } from 'wouter'

export default function Home() {
  const [, setLoc] = useLocation()
  const [term, setTerm] = useState('')

  const go = () => {
    const q = term.trim()
    setLoc(q ? `/buscar?nome=${encodeURIComponent(q)}` : '/buscar')
  }

  return (
    <div className="container mx-auto p-6">
      <div className="text-sm mb-2"><Link href="/buscar">(demonstrar busca)</Link></div>
      <h1 className="text-3xl font-bold mb-6">Votações do Congresso</h1>
      <div className="flex gap-2 max-w-2xl">
        <input
          value={term}
          onChange={(e) => setTerm(e.target.value)}
          placeholder="Ex.: João Silva"
          className="border rounded px-3 py-2 flex-1"
        />
        <button onClick={go} className="px-4 py-2 rounded bg-black text-white">Buscar</button>
      </div>
    </div>
  )
}
