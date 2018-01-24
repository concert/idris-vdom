module VirtualDOM.Test.Main

import Specdris.SpecIO
import VirtualDOM
import VirtualDOM.DOM

{-
Things to test:

☑ Single element is created
☑ Nested elements are created
☐ Events work on elements
☐ Properties are created on element
☐ Node is created on different root than body
-}

querySelector : String -> JS_IO Ptr
querySelector = jscall "document.querySelector(%0)" _

isNull : Ptr -> JS_IO Bool
isNull ptr = (== "true") <$>
  jscall "(%0 === null) + ''" (Ptr -> JS_IO String) ptr

selectorExists : String -> JS_IO Bool
selectorExists selector = not <$> (querySelector selector >>= isNull)

assertSelect : (shouldExist : Bool) -> (selector : String) ->
                          JS_IO SpecResult
assertSelect shouldExist selector = do
  exists <- selectorExists selector
  let reason =
    if shouldExist
      then "selector should match elements"
      else "selector should not match elements"
  if exists == shouldExist
    then pure Success
    else pure $ UnaryFailure selector reason

shouldSelect : String -> JS_IO SpecResult
shouldSelect = assertSelect True

shouldNotSelect : String -> JS_IO SpecResult
shouldNotSelect = assertSelect False

infixl 2 `collectResult`

collectResult : JS_IO SpecResult -> JS_IO SpecResult -> JS_IO SpecResult
collectResult resIO1 resIO2 = do
  res1 <- resIO1
  res2 <- resIO2
  pure $ do
    res1
    res2

elementsSpec : SpecTree' FFI_JS
elementsSpec =
  describe "elements" $ do
    it "creates a single element" $ do
      program $ node "p" [] [] []
      shouldSelect "p"
    it "creates a nested element" $ do
      program $ node "p" [] [] [ node "span" [] [] []
                               ]
      shouldSelect "p > span"
    it "creates elements in the given order" $ do
      program $ node "div" [] [] [ node "p" [] [] []
                                 , node "span" [] [] []
                                 ]
      shouldSelect "p:nth-child(1)"
        `collectResult` shouldSelect "span:nth-child(2)"

propertiesSpec : SpecTree' FFI_JS
propertiesSpec =
  describe "properties" $ do
    it "sets a single property on an element" $ do
      program $ node "p" [] [("class", "testval")] []
      shouldSelect "p.testval"
    it "overwrites properties with duplicate keys" $ do
      program $ node "p" [] [ ("class", "badval")
                            , ("class", "goodval")
                            ] []
      shouldNotSelect "p.badval"
        `collectResult` shouldSelect "p.goodval"
    it "sets multiple properties on an element" $ do
      program $ node "p" [] [ ("class", "classval")
                            , ("title", "titleval")
                            ] []
      shouldSelect "p.classval[title=titleval]"
    it "sets different properties on multiple elements" $ do
      program $ node "div" [] [] [ node "p" [] [("class", "a")] []
                                 , node "p" [] [("class", "b")] []
                                 ]
      shouldSelect "p.a"
        `collectResult` shouldSelect "p.b"
        `collectResult` shouldNotSelect "p.a.b"

main : JS_IO ()
main = specIO' $ do
  describe "virtual DOM" $ do
    elementsSpec
    propertiesSpec