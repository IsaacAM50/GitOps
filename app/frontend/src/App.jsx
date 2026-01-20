import React, { useState } from 'react';
import { Rocket, GitBranch, CheckCircle, AlertCircle, Loader, ExternalLink, Sparkles, Terminal, Code2 } from 'lucide-react';

function App() {
  const [username, setUsername] = useState('');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);

  const handleDeploy = async (e) => {
    e.preventDefault();
    
    if (!username || username.length < 2) {
      setError('Por favor ingresa un nombre válido (mínimo 2 caracteres)');
      return;
    }

    setLoading(true);
    setError(null);
    setResult(null);

    try {
      const response = await fetch('http://localhost:8000/api/deploy', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ username }),
      });

      const data = await response.json();

      if (response.ok) {
        setResult(data);
      } else {
        setError(data.detail || 'Error al iniciar deployment');
      }
    } catch (err) {
      setError('Error de conexión con el backend. ¿Está corriendo en localhost:8000?');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
      {/* Animated background effect */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-40 -right-40 w-80 h-80 bg-purple-500 rounded-full mix-blend-multiply filter blur-xl opacity-20 animate-blob"></div>
        <div className="absolute -bottom-40 -left-40 w-80 h-80 bg-pink-500 rounded-full mix-blend-multiply filter blur-xl opacity-20 animate-blob animation-delay-2000"></div>
        <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-80 h-80 bg-blue-500 rounded-full mix-blend-multiply filter blur-xl opacity-20 animate-blob animation-delay-4000"></div>
      </div>

      {/* Header */}
      <header className="relative border-b border-white/10 backdrop-blur-sm bg-white/5">
        <div className="container mx-auto px-4 py-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-gradient-to-br from-purple-500 to-pink-500 rounded-lg">
                <Rocket className="w-8 h-8 text-white" />
              </div>
              <div>
                <h1 className="text-2xl font-bold text-white">GitOps Platform</h1>
                <p className="text-sm text-purple-300">Deploy tu propia versión con un click</p>
              </div>
            </div>
            <div className="hidden md:flex items-center gap-2">
              <Code2 className="w-5 h-5 text-purple-400" />
              <span className="text-sm text-purple-300">DevOps Portfolio Project</span>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="relative container mx-auto px-4 py-12">
        <div className="max-w-4xl mx-auto">
          {/* Hero Section */}
          <div className="text-center mb-12">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-purple-500/20 border border-purple-500/30 rounded-full mb-6">
              <Sparkles className="w-4 h-4 text-purple-400" />
              <span className="text-sm text-purple-300">Powered by Kubernetes, CircleCI & ArgoCD</span>
            </div>
            
            <h2 className="text-5xl md:text-6xl font-bold text-white mb-4 bg-gradient-to-r from-purple-400 to-pink-400 bg-clip-text text-transparent">
              Tu Deployment Personalizado
            </h2>
            <p className="text-xl text-purple-200 mb-8 max-w-2xl mx-auto">
              Ingresa tu nombre y observa cómo GitOps despliega tu versión automatizada en tiempo real
            </p>
            
            {/* Tech Stack Badges */}
            <div className="flex flex-wrap justify-center gap-2 mb-8">
              {[
                { name: 'Kubernetes', color: 'from-blue-500 to-blue-600' },
                { name: 'CircleCI', color: 'from-gray-700 to-gray-800' },
                { name: 'ArgoCD', color: 'from-orange-500 to-red-500' },
                { name: 'Docker', color: 'from-blue-400 to-blue-500' },
                { name: 'React', color: 'from-cyan-400 to-cyan-500' },
                { name: 'FastAPI', color: 'from-green-500 to-emerald-500' }
              ].map((tech) => (
                <span
                  key={tech.name}
                  className={`px-3 py-1 bg-gradient-to-r ${tech.color} text-white rounded-full text-sm font-medium shadow-lg`}
                >
                  {tech.name}
                </span>
              ))}
            </div>
          </div>

          {/* Main Card */}
          <div className="relative bg-white/10 backdrop-blur-md rounded-2xl shadow-2xl border border-white/20 p-8 mb-8">
            {/* Decorative gradient */}
            <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-purple-500 via-pink-500 to-purple-500 rounded-t-2xl"></div>
            
            <form onSubmit={handleDeploy} className="space-y-6">
              <div>
                <label htmlFor="username" className="block text-sm font-medium text-purple-200 mb-2">
                  Tu Nombre
                </label>
                <div className="relative">
                  <input
                    id="username"
                    type="text"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    placeholder="Ej: Isaac"
                    className="w-full px-4 py-4 bg-white/5 border-2 border-white/20 rounded-xl text-white placeholder-white/40 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all"
                    disabled={loading}
                  />
                  <Terminal className="absolute right-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-purple-400" />
                </div>
              </div>

              <button
                type="submit"
                disabled={loading || !username}
                className="w-full group relative flex items-center justify-center gap-2 px-6 py-4 bg-gradient-to-r from-purple-600 to-pink-600 text-white font-semibold rounded-xl hover:from-purple-700 hover:to-pink-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all transform hover:scale-[1.02] active:scale-[0.98] shadow-lg hover:shadow-purple-500/50"
              >
                {loading ? (
                  <>
                    <Loader className="w-5 h-5 animate-spin" />
                    <span>Iniciando Deployment...</span>
                  </>
                ) : (
                  <>
                    <Rocket className="w-5 h-5 group-hover:rotate-12 transition-transform" />
                    <span>Desplegar Mi Versión</span>
                  </>
                )}
              </button>
            </form>

            {/* Success Message */}
            {result && (
              <div className="mt-6 p-6 bg-green-500/20 border border-green-500/30 rounded-xl animate-fadeIn">
                <div className="flex items-start gap-3">
                  <CheckCircle className="w-6 h-6 text-green-400 flex-shrink-0 mt-0.5" />
                  <div className="flex-1">
                    <p className="text-green-300 font-medium mb-2">{result.message}</p>
                    {result.pipeline_url && (
                      <a
                        href={result.pipeline_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="inline-flex items-center gap-2 px-4 py-2 bg-green-500/20 hover:bg-green-500/30 border border-green-500/30 rounded-lg text-sm text-green-300 hover:text-green-200 transition-all"
                      >
                        <ExternalLink className="w-4 h-4" />
                        Ver pipeline en CircleCI
                      </a>
                    )}
                    <div className="mt-4 p-4 bg-black/20 rounded-lg border border-green-500/20">
                      <p className="text-xs text-green-400 font-mono">Pipeline ID: {result.pipeline_id}</p>
                      <p className="text-xs text-green-300 mt-1">
                        ⏱️ Tiempo estimado: 5-10 minutos
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* Error Message */}
            {error && (
              <div className="mt-6 p-6 bg-red-500/20 border border-red-500/30 rounded-xl animate-fadeIn">
                <div className="flex items-start gap-3">
                  <AlertCircle className="w-6 h-6 text-red-400 flex-shrink-0 mt-0.5" />
                  <div>
                    <p className="text-red-300 font-medium">{error}</p>
                    <p className="text-sm text-red-400 mt-2">
                      Verifica que el backend esté corriendo y que hayas configurado correctamente el .env
                    </p>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* How it Works */}
          <div className="grid md:grid-cols-3 gap-6">
            {[
              {
                icon: GitBranch,
                title: '1. Trigger Pipeline',
                description: 'CircleCI recibe tu nombre y construye una imagen Docker personalizada con tu configuración',
                color: 'from-purple-500 to-purple-600'
              },
              {
                icon: Rocket,
                title: '2. Update Manifests',
                description: 'Los manifiestos de Kubernetes se actualizan automáticamente en Git con tu deployment',
                color: 'from-pink-500 to-pink-600'
              },
              {
                icon: CheckCircle,
                title: '3. ArgoCD Deploy',
                description: 'ArgoCD detecta cambios en Git y despliega tu versión personalizada en el cluster',
                color: 'from-green-500 to-green-600'
              }
            ].map((step, idx) => (
              <div key={idx} className="group relative bg-white/5 backdrop-blur-sm rounded-xl p-6 border border-white/10 hover:border-purple-500/50 transition-all hover:shadow-xl hover:shadow-purple-500/20">
                <div className={`w-12 h-12 bg-gradient-to-br ${step.color} rounded-lg flex items-center justify-center mb-4 group-hover:scale-110 transition-transform`}>
                  <step.icon className="w-6 h-6 text-white" />
                </div>
                <h3 className="text-lg font-semibold text-white mb-2">{step.title}</h3>
                <p className="text-purple-200 text-sm leading-relaxed">{step.description}</p>
              </div>
            ))}
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="relative border-t border-white/10 mt-20">
        <div className="container mx-auto px-4 py-8">
          <div className="text-center">
            <p className="text-purple-300 text-sm mb-2">
              Creado por <span className="font-semibold text-white">Isaac Mensah Adams</span> - DevOps Engineer
            </p>
            <div className="flex justify-center gap-4 text-sm">
              <a
                href="https://www.linkedin.com/in/isaac-adams-mensah4935a9237/"
                target="_blank"
                rel="noopener noreferrer"
                className="text-purple-400 hover:text-purple-300 transition"
              >
                LinkedIn
              </a>
              <span className="text-purple-600">|</span>
              <a
                href="https://github.com/isaac-adams"
                target="_blank"
                rel="noopener noreferrer"
                className="text-purple-400 hover:text-purple-300 transition"
              >
                GitHub
              </a>
              <span className="text-purple-600">|</span>
              <a
                href="mailto:isaac.adams@blueoption.io"
                className="text-purple-400 hover:text-purple-300 transition"
              >
                Email
              </a>
            </div>
          </div>
        </div>
      </footer>

      <style>{`
        @keyframes blob {
          0%, 100% { transform: translate(0, 0) scale(1); }
          25% { transform: translate(20px, -50px) scale(1.1); }
          50% { transform: translate(-20px, 20px) scale(0.9); }
          75% { transform: translate(50px, 50px) scale(1.05); }
        }
        
        .animate-blob {
          animation: blob 7s infinite;
        }
        
        .animation-delay-2000 {
          animation-delay: 2s;
        }
        
        .animation-delay-4000 {
          animation-delay: 4s;
        }
        
        @keyframes fadeIn {
          from {
            opacity: 0;
            transform: translateY(10px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
        
        .animate-fadeIn {
          animation: fadeIn 0.5s ease-out;
        }
      `}</style>
    </div>
  );
}

export default App;