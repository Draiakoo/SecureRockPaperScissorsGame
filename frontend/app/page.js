"use client"
import Image from 'next/image'
import ActionList from '@components/ActionList'
import Animation from '@components/Animation'
import "@styles/globals.css"
import { actionListNames } from "@actionList"

export default function Home() {

  return (
    <div className="bg-gradient-to-b from-cyan-400 to-cyan-900">
        <h1 className="text-center underline p-5 text-4xl font-bold">
          Rock Paper Scissors Game
        </h1>
        <Animation/>
        <ActionList list={actionListNames}/>
    </div>
  )
}
