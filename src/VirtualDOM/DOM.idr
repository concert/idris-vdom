module VirtualDOM.DOM

%default total
%access export

export
record Node where
  constructor MkNode
  unNode : Ptr

%inline
jscall : (name : String) -> (ty : Type) -> {auto fty : FTy FFI_JS [] ty} ->ty
jscall name ty = foreign FFI_JS name ty

documentBody : JS_IO Node
documentBody = MkNode <$> jscall "document.body" _

getElementById : (elementId : String) -> JS_IO Node
getElementById elementId = MkNode <$>
  jscall "document.getElementById(%0)"
    (String -> JS_IO Ptr) elementId

appendChild : (parent : Node) -> (child : Node) -> JS_IO Node
appendChild parent child = MkNode <$>
  jscall "(%0).appendChild(%1)" (Ptr -> Ptr -> JS_IO Ptr)
  (unNode parent) (unNode child)

setAttribute : Node -> (name : String) -> (value : String) -> JS_IO ()
setAttribute = jscall "%0.setAttribute(%1, %2)"
  (Ptr -> String -> String -> JS_IO ()) . unNode

createElement : (tag : String) -> JS_IO Node
createElement = liftA MkNode . jscall "document.createElement(%0)" _

createTextNode : (text : String) -> JS_IO Node
createTextNode = liftA MkNode . jscall "document.createTextNode(%0)" _

setInnerHTML : (element : Node) -> (html : String) -> JS_IO ()
setInnerHTML = jscall "%0.innerHTML = %1" (Ptr -> String -> JS_IO ()) . unNode

record ListenerOptions where
  constructor MkListenerOptions
  once : Maybe Bool

noOptions : ListenerOptions
noOptions = MkListenerOptions Nothing

jsonParse : (json : String) -> JS_IO Ptr
jsonParse = jscall "JSON.parse(%0)" _

partial
addEventListener : (eventTarget : Node) -> (eventName : String) ->
                   (listener : Ptr -> JS_IO ()) ->
                   (options : ListenerOptions) ->
                   JS_IO ()
addEventListener eventTarget eventName listener options = do
  let optString = case once options of
                       Nothing => "{}"
                       Just False => """{"once":false}"""
                       Just True => """{"once":true}"""
  optObj <- jsonParse optString
  jscall "%0.addEventListener(%1, %2, %3)"
    (Ptr -> String -> JsFn (Ptr -> JS_IO ()) -> Ptr -> JS_IO ())
    (unNode eventTarget) eventName (MkJsFn listener) optObj
    
dispatchSimpleEvent : (eventName : String) -> (eventTarget : Node) -> JS_IO Bool
dispatchSimpleEvent eventName eventTarget = do
  sbool <- jscall "%0.dispatchEvent(new Event(%1)).toString()"
    (Ptr -> String -> JS_IO String) (unNode eventTarget) eventName
  pure $ sbool == "true"