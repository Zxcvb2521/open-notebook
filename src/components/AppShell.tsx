import React from 'react'

interface AppShellProps {
  children: React.ReactNode
}

export const AppShell: React.FC<AppShellProps> = ({ children }) => {
  return (
    <div className="flex h-screen overflow-hidden bg-gray-100">
      {/* Sidebar - simple placeholder */}
      <aside className="w-64 bg-white border-r flex flex-col">
        <div className="p-4 border-b">
          <h1 className="font-bold text-lg">Open Notebook</h1>
        </div>
        <nav className="flex-1 p-2">
          {/* Simple navigation */}
          <a href="#" className="block px-3 py-2 rounded hover:bg-gray-100">Dashboard</a>
          <a href="#/notebooks" className="block px-3 py-2 rounded hover:bg-gray-100">Notebooks</a>
          <a href="#/sources" className="block px-3 py-2 rounded hover:bg-gray-100">Sources</a>
          <a href="#/podcasts" className="block px-3 py-2 rounded hover:bg-gray-100">Podcasts</a>
        </nav>
      </aside>

      {/* Main content area */}
      <main className="flex-1 flex flex-col min-h-0 overflow-hidden">
        {children}
      </main>
    </div>
  )
}

export default AppShell