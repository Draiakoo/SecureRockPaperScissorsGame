import "@styles/globals.css"
import Link from "next/link"
import Image from "next/image"

const Nav = () => {
  return (
    <nav className="bg-cyan-900">
        <div className="flex-between w-full px-10 py-3 ">
            <Link href="/balance-dashboard" className="flex gap-2 flex-center">
            <Image 
            src="/game_logo.jpg"
            alt="Promptopia Logo"
            width={30}
            height={30}
            className="object-contain rounded-full"
            />
            <p className="logo_text">Balance dashboard</p>
            </Link>
            <p className="logo_text">Your balance: 5 ETH</p>
            <button className="custom-button">
                Connect wallet
            </button>
        </div>
        
    </nav>
  )
}

export default Nav