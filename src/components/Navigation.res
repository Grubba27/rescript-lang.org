module Link = Next.Link

let link = "no-underline block text-inherit hover:cursor-pointer hover:text-fire-30 text-gray-40 mb-px"
let activeLink = "text-inherit font-medium text-fire-30 border-b border-fire"

let linkOrActiveLink = (~target, ~route) => target === route ? activeLink : link

let linkOrActiveLinkSubroute = (~target, ~route) =>
  Js.String2.startsWith(route, target) ? activeLink : link

let linkOrActiveApiSubroute = (~route) => {
  let url = Url.parse(route)
  switch Belt.Array.get(url.pagepath, 0) {
  | Some("api") => activeLink
  | _ => link
  }
}

let isDocsSubroute = route => {
  let url = Url.parse(route)
  switch url {
  | {base: ["docs"]}
  | {base: ["docs", "gentype"]}
  | {base: ["docs", "manual"]} =>
    switch Belt.Array.get(url.pagepath, 0) {
    | Some("api") => false
    | _ => true
    }
  | _ => false
  }
}

let linkOrActiveDocsSubroute = (~route) => {
  let url = Url.parse(route)
  switch url {
  | {base: ["docs"]}
  | {base: ["docs", "gentype"]}
  | {base: ["docs", "manual"]} =>
    switch Belt.Array.get(url.pagepath, 0) {
    | Some("api") => link
    | _ => activeLink
    }
  | _ => link
  }
}

let githubHref = "https://github.com/reason-association/rescript-lang.org#rescript-langorg"
//let twitterHref = "https://twitter.com/rescriptlang"
let discourseHref = "https://forum.rescript-lang.org"

module CollapsibleLink = {
  // KeepOpen = Menu has been opened and should stay open
  type state =
    | KeepOpen
    | HoverOpen
    | Closed

  @react.component
  let make = (
    ~title: string,
    ~onStateChange: (~id: string, state) => unit,
    ~allowHover=true,
    /* ~allowInteraction=true, */
    ~id: string,
    ~state: state,
    ~active=false,
    ~children,
  ) => {
    // This is not onClick, because we want to prevent
    // text selection on multiple clicks
    let onMouseDown = evt => {
      ReactEvent.Mouse.preventDefault(evt)
      ReactEvent.Mouse.stopPropagation(evt)

      onStateChange(
        ~id,
        switch state {
        | Closed => KeepOpen
        | HoverOpen => Closed
        | KeepOpen => Closed
        },
      )
    }

    let onMouseEnter = evt => {
      ReactEvent.Mouse.preventDefault(evt)
      if allowHover {
        onStateChange(~id, HoverOpen)
      }
    }

    let isOpen = switch state {
    | Closed => false
    | KeepOpen
    | HoverOpen => true
    }

    // This onClick is required for iOS12 safari.
    // There seems to be a bug where mouse events
    // won't be registered, unless an onClick event
    // is attached
    // DO NOT REMOVE, OTHERWISE THE COLLAPSIBLE WON'T WORK
    let onClick = _ => ()

    <div className="relative" onMouseEnter>
      <div className="flex items-center">
        <a
          onMouseDown
          onClick
          className={(active ? activeLink : link) ++
          (" border-none flex items-center hover:cursor-pointer " ++
          (isOpen ? " text-gray-20" : ""))}>
          <span className={active ? "border-b border-fire" : ""}> {React.string(title)} </span>
        </a>
      </div>
      <div
        className={(
          isOpen ? "flex" : "hidden"
        ) ++ " fixed left-0 border-gray-80 border-t bg-white rounded-bl-xl rounded-br-xl shadow-sm min-w-320 w-full h-full sm:h-auto sm:justify-center"}
        style={ReactDOMStyle.make(~marginTop="1rem", ())}>
        <div className="w-full"> children </div>
      </div>
    </div>
  }
}

let useOutsideClick: (ReactDOM.Ref.t, unit => unit) => unit = %raw(j`(outerRef, trigger) => {
      function handleClickOutside(event) {
        if (outerRef.current && !outerRef.current.contains(event.target)) {
          trigger();
        }
      }

      React.useEffect(() => {
        document.addEventListener("mousedown", handleClickOutside);
        return () => {
          document.removeEventListener("mousedown", handleClickOutside);
        };
      });

    }`)

let useWindowWidth: unit => option<int> = %raw(j` () => {
  const isClient = typeof window === 'object';

  function getSize() {
    return {
      width: isClient ? window.innerWidth : undefined,
      height: isClient ? window.innerHeight : undefined
    };
  }

  const [windowSize, setWindowSize] = React.useState(getSize);

  React.useEffect(() => {
    if (!isClient) {
      return false;
    }

    function handleResize() {
      setWindowSize(getSize());
    }

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []); // Empty array ensures that effect is only run on mount and unmount

  if(windowSize) {
    return windowSize.width;
  }
  return null;
  }
  `)

type collapsible = {
  title: string,
  children: React.element,
  isActiveRoute: string => bool,
  href: string,
  state: CollapsibleLink.state,
}

module DocsSection = {
  @react.component
  let make = () => {
    let router = Next.Router.useRouter()
    let url = router.route->Url.parse

    let (version, setVersion) = React.useState(_ =>
      switch url.version {
      | Url.Latest => "latest"
      | NoVersion => "latest"
      | Version(version) => version
      }
    )

    let languageManual = Constants.languageManual(version)

    let column = (~title: string, children: React.element) => {
      <div className="">
        <div className="text-12 font-medium text-gray-100 tracking-wide uppercase">
          {React.string(title)}
        </div>
        <div> {children} </div>
      </div>
    }

    let onVersionChange = evt => {
      open Url
      ReactEvent.Form.preventDefault(evt)
      let version = (evt->ReactEvent.Form.target)["value"]

      let targetUrl =
        "/" ++
        (Js.Array2.joinWith(url.base, "/") ++
        ("/" ++ (version ++ ("/" ++ Js.Array2.joinWith(url.pagepath, "/")))))

      setVersion(_ => version)
      /* router->Next.Router.push(targetUrl) */
    }

    <div className="w-full bg-white text-gray-40 text-14">
      <div className={"flex justify-center w-full py-2 border-b border-gray-10"}>
        <div className="w-full space-x-2 max-w-1280 ">
          <VersionSelect
            availableVersions=Constants.allManualVersions onChange=onVersionChange version
          />
          {switch version {
          | "latest" =>
            <span className="text-gray-40 text-12">
              {React.string("This is the latest docs version")}
            </span>
          | _ => React.null
          }}
        </div>
      </div>
      <div className="flex justify-center pt-8 pb-10">
        <div className="w-full grid grid-cols-3 max-w-1280">
          {<ul className="space-y-1 ml-2 mt-4">
            {languageManual
            ->Js.Array2.map(item => {
              let (text, href) = item

              let linkClass = if router.route === href {
                "text-fire"
              } else {
                "hover:text-fire"
              }

              <li key=text>
                <span className="text-fire mr-2"> {React.string(`-`)} </span>
                <Link href> <a className=linkClass> {React.string(text)} </a> </Link>
              </li>
            })
            ->React.array}
          </ul>->column(~title="Language Manual")}
          {<ul />->column(~title="Ecosystem")}
          {<ul />->column(~title="Tools")}
        </div>
      </div>
    </div>
  }
}

module MobileNav = {
  @react.component
  let make = (~route: string) => {
    let base = "font-normal mx-4 py-5 text-gray-20 border-b border-gray-80"
    let extLink = "block hover:cursor-pointer hover:text-white text-gray-60"
    <div className="border-gray-80 border-t">
      <ul>
        <li className=base> <DocSearch.Textbox id="docsearch-mobile" /> </li>
        <li className=base>
          <Link href="/try">
            <a className={linkOrActiveLink(~target="/try", ~route)}>
              {React.string("Playground")}
            </a>
          </Link>
        </li>
        <li className=base>
          <Link href="/blog">
            <a className={linkOrActiveLinkSubroute(~target="/blog", ~route)}>
              {React.string("Blog")}
            </a>
          </Link>
        </li>
        /*
         <li className=base>
           <Link href="/community">
             <a className={linkOrActiveLink(~target="/community", ~route)}>
               {React.string("Community")}
             </a>
           </Link>
         </li>
 */
        <li className=base>
          <a
            href="https://twitter.com/rescriptlang"
            rel="noopener noreferrer"
            target="_blank"
            className=extLink>
            {React.string("Twitter")}
          </a>
        </li>
        <li className=base>
          <a href=githubHref rel="noopener noreferrer" target="_blank" className=extLink>
            {React.string("Github")}
          </a>
        </li>
        <li className=base>
          <a href=discourseHref rel="noopener noreferrer" target="_blank" className=extLink>
            {React.string("Forum")}
          </a>
        </li>
      </ul>
    </div>
  }
}

/* isOverlayOpen: if the mobile overlay is toggled open */
@react.component
let make = (~fixed=true, ~overlayState: (bool, (bool => bool) => unit)) => {
  let minWidth = "20rem"
  let router = Next.Router.useRouter()

  let route = router.route

  let (collapsibles, setCollapsibles) = React.useState(_ => [
    {
      title: "Docs",
      href: "/docs/manual/latest/api",
      isActiveRoute: route => {
        isDocsSubroute(route)
      },
      state: KeepOpen,
      children: <DocsSection />,
    },
  ])

  let (isOverlayOpen, setOverlayOpen) = overlayState

  let toggleOverlay = () => setOverlayOpen(prev => !prev)

  let resetCollapsibles = () =>
    setCollapsibles(prev => Belt.Array.map(prev, c => {...c, state: Closed}))

  let outerRef = React.useRef(Js.Nullable.null)
  useOutsideClick(ReactDOM.Ref.domRef(outerRef), resetCollapsibles)

  let windowWidth = useWindowWidth()

  // Don't allow hover behavior for collapsibles if mobile navigation is on
  let allowHover = switch windowWidth {
  | Some(width) => width > 576 // Value noted in tailwind config
  | None => true
  }

  let nonCollapsibleOnMouseEnter = evt => {
    ReactEvent.Mouse.preventDefault(evt)
    resetCollapsibles()
  }

  // Client side navigation requires us to reset the collapsibles
  // whenever a route change had occurred, otherwise the collapsible
  // will stay open, even though you clicked a link
  React.useEffect1(() => {
    open Next.Router.Events
    let {Next.Router.events: events} = router

    let onChangeComplete = _url => {
      resetCollapsibles()
      setOverlayOpen(_ => false)
    }

    events->on(#routeChangeComplete(onChangeComplete))
    events->on(#hashChangeComplete(onChangeComplete))

    Some(
      () => {
        events->off(#routeChangeComplete(onChangeComplete))
        events->off(#hashChangeComplete(onChangeComplete))
      },
    )
  }, [])

  let fixedNav = fixed ? "fixed z-30 top-0" : ""

  let onStateChange = (~id, state) => {
    setCollapsibles(prev => {
      Js.Array2.reduce(
        prev,
        (acc, next) => {
          if next.title === id {
            acc
            ->Js.Array2.push({
              ...next,
              state: state,
            })
            ->ignore
          } else {
            ()
          }

          acc
        },
        [],
      )
    })
    ()
  }

  let collapsibleElements = Js.Array2.map(collapsibles, coll => {
    <CollapsibleLink
      key={coll.title}
      title={coll.title}
      state={coll.state}
      id={coll.title}
      allowHover={allowHover}
      active={coll.isActiveRoute(route)}
      onStateChange>
      {coll.children}
    </CollapsibleLink>
  })

  <nav
    ref={ReactDOM.Ref.domRef(outerRef)}
    id="header"
    style={ReactDOMStyle.make(~minWidth, ())}
    className={fixedNav ++ " flex xs:justify-center w-full h-16 bg-gray-95 shadow text-white-80 text-14"}>
    <div className="flex justify-between mx-4 md:mx-8 items-center h-full w-full max-w-1280">
      <div className="h-8 w-8 lg:h-10 lg:w-32">
        <a
          href="/"
          className="block hover:cursor-pointer w-full h-full flex justify-center items-center font-bold">
          <img src="/static/nav-logo@2x.png" className="lg:hidden" />
          <img src="/static/nav-logo-full@2x.png" className="hidden lg:block" />
        </a>
      </div>
      /* Desktop horizontal navigation */
      <div className="flex items-center xs:justify-between w-full bg-gray-95 sm:h-auto sm:relative">
        <div
          className="flex ml-10 space-x-5 w-full max-w-320"
          style={ReactDOMStyle.make(~maxWidth="26rem", ())}>
          {collapsibleElements->React.array}
          /* <Link href="/docs/latest"> */
          /* <a */
          /* className={"mr-5 " ++ linkOrActiveDocsSubroute(~route)} */
          /* onMouseEnter=nonCollapsibleOnMouseEnter> */
          /* {React.string("Docs")} */
          /* </a> */
          /* </Link> */
          <Link href="/docs/manual/latest/api">
            <a className={linkOrActiveApiSubroute(~route)} onMouseEnter=nonCollapsibleOnMouseEnter>
              {React.string("API")}
            </a>
          </Link>
          <Link href="/try">
            <a
              className={"hidden xs:block " ++ linkOrActiveLink(~target="/try", ~route)}
              onMouseEnter=nonCollapsibleOnMouseEnter>
              {React.string("Playground")}
            </a>
          </Link>
          <Link href="/blog">
            <a
              className={"hidden xs:block " ++ linkOrActiveLinkSubroute(~target="/blog", ~route)}
              onMouseEnter=nonCollapsibleOnMouseEnter>
              {React.string("Blog")}
            </a>
          </Link>
          <Link href="/community">
            <a
              className={"hidden xs:block " ++ linkOrActiveLink(~target="/community", ~route)}
              onMouseEnter=nonCollapsibleOnMouseEnter>
              {React.string("Community")}
            </a>
          </Link>
        </div>
        <div className="hidden md:flex items-center">
          <div className="hidden sm:block mr-6"> <DocSearch /> </div>
          <a
            href=githubHref
            rel="noopener noreferrer"
            target="_blank"
            className={"mr-5 " ++ link}
            onMouseEnter=nonCollapsibleOnMouseEnter>
            <Icon.Github className="w-6 h-6 opacity-50 hover:opacity-100" />
          </a>
          <a
            href="https://twitter.com/rescriptlang"
            rel="noopener noreferrer"
            target="_blank"
            className={"mr-5 " ++ link}
            onMouseEnter=nonCollapsibleOnMouseEnter>
            <Icon.Twitter className="w-6 h-6 opacity-50 hover:opacity-100" />
          </a>
          <a
            href=discourseHref
            rel="noopener noreferrer"
            target="_blank"
            className=link
            onMouseEnter=nonCollapsibleOnMouseEnter>
            <Icon.Discourse className="w-6 h-6 opacity-50 hover:opacity-100" />
          </a>
        </div>
      </div>
    </div>
    /* Burger Button */
    <button
      className="h-full px-4 xs:hidden flex items-center hover:text-white"
      onClick={evt => {
        ReactEvent.Mouse.preventDefault(evt)
        resetCollapsibles()
        toggleOverlay()
      }}>
      <Icon.DrawerDots className={"h-1 w-auto block " ++ (isOverlayOpen ? "text-fire" : "")} />
    </button>
    /* Mobile overlay */
    <div
      style={ReactDOMStyle.make(~minWidth, ~top="4rem", ())}
      className={(
        isOverlayOpen ? "flex" : "hidden"
      ) ++ " sm:hidden flex-col fixed top-0 left-0 h-full w-full z-30 sm:w-9/12 bg-gray-100 sm:h-auto sm:flex sm:relative sm:flex-row sm:justify-between"}>
      <MobileNav route />
    </div>
  </nav>
}
