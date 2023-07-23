import Image from 'next/image'
import ActionList from '@components/ActionList'
import "@styles/globals.css"
import { actionListNames } from "@actionList"

export default function Home() {
  return (
    <div className="bg-gradient-to-b from-cyan-400 to-cyan-900">
        <h1 className="text-center underline py-5 text-4xl font-bold">
          Rock Paper Scissors Game
        </h1>
        <div className="bg-white rounded-lg inline-block mb-5 ml-auto">
          <Image
            src={"/image-transition/animation_pattern.png"}
            width={800}
            height={100}
          />
        </div>
        <ActionList list={actionListNames}/>
    </div>
  )
}
