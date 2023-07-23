import "@styles/globals.css"


const ActionList = ({list}) => {
  return (
    <div>
        {list.map((action) => {
            return(
                <div className="container flex justify-center items-center">
                    <a className="my-2 professional-link" href={action.href}>
                        {"> " + action.action}
                    </a>
                </div>
            )
        })}
    </div>
  )
}

export default ActionList