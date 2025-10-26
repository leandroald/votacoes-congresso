import React from 'react'
import ReactDOM from 'react-dom/client'
import { Route, Switch } from 'wouter'
import Home from '@/pages/Home'
import Buscar from '@/pages/Buscar'
import DeputadoPage from '@/pages/Deputado'

import './index.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <Switch>
      <Route path="/" component={Home} />
      <Route path="/buscar" component={Buscar} />
      <Route path="/deputado/:id" component={DeputadoPage} />
      <Route>404 - Página não encontrada</Route>
    </Switch>
  </React.StrictMode>
)
