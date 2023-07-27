"use client"

import Image from "next/image"
import { useState, useEffect } from 'react'
import "@styles/globals.css"

const Animation = () => {

    const imageUrls = [
        '/image-transition/cut_animation_1.png',
        '/image-transition/cut_animation_2.png',
        '/image-transition/cut_animation_3.png',
        '/image-transition/cut_animation_4.png',
        '/image-transition/cut_animation_5.png',
        '/image-transition/cut_animation_6.png',
        '/image-transition/cut_animation_7.png',
      ];
      
    const [currentImageIndex, setCurrentImageIndex] = useState(0);
      
    useEffect(() => {
        setInterval(() => {
            setCurrentImageIndex(prevIndex => ((prevIndex + 1) % imageUrls.length));
        }, 3000);
        return () => clearInterval(interval);
    }, []);

  return (
    <div className="flex justify-center items-center mb-14">
        <div className="bg-white rounded-lg inline-block imageContainer">
            {imageUrls.map((url, index) => (
            <img
                key={index}
                src={url}
                alt={`Image ${index}`}
                className={`image p-7 ${currentImageIndex === index ? "active z-10" : "z-0"}`}
            />
            ))}
        </div>
    </div>
  )
}

export default Animation
