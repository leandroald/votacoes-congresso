import { Route, Switch } from "wouter";
import Home from "./pages/Home";
import BuscarDeputados from "./pages/BuscarDeputados";

function App() {
  return (
    <Switch>
      <Route path="/" component={Home} />
      <Route path="/deputados" component={BuscarDeputados} />
      <Route>
        <div className="min-h-screen flex items-center justify-center">
          <div className="text-center">
            <h1 className="text-4xl font-bold mb-4">404</h1>
            <p className="text-muted-foreground">Página não encontrada</p>
          </div>
        </div>
      </Route>
    </Switch>
  );
}

export default App;

