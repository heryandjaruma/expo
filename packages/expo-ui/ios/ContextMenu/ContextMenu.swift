import SwiftUI
import ExpoModulesCore

struct MenuItems: View {
  let fromElements: [ContextMenuElement]?
  let props: ContextMenuProps?
  // We have to create a non-functional shadow node proxy, so that the elements don't send sizing changes to the
  // root proxy - we won't be leaving the SwiftUI hierarchy.
  let shadowNodeProxy = ExpoSwiftUI.ShadowNodeProxy()

  init(fromElements: [ContextMenuElement]?, props: ContextMenuProps?) {
    self.fromElements = fromElements
    self.props = props

    fromElements?.forEach { element in
      let id = element.contextMenuElementID
      if let button = element.button {
        button.onButtonPressed.onEventSent = { _ in
          props?.onContextMenuButtonPressed(addId(id, toMap: nil))
        }
      }
      if let `switch` = element.switch {
        `switch`.onValueChange.onEventSent = { map in
          props?.onContextMenuSwitchCheckedChanged(addId(id, toMap: map))
        }
      }
      if let picker = element.picker {
        picker.onOptionSelected.onEventSent = { map in
          props?.onContextMenuPickerOptionSelected(addId(id, toMap: map))
        }
      }
    }
  }

  var body: some View {
    ForEach(fromElements ?? []) { elem in
      if let button = elem.button {
        ExpoUI.Button(props: button)
      }

      if let picker = elem.picker {
        ExpoUI.PickerView(props: picker)
      }

      if let `switch` = elem.switch {
        ExpoUI.SwitchView(props: `switch`).environmentObject(shadowNodeProxy)
      }

      if let submenu = elem.submenu {
        SinglePressContextMenu(
          elements: submenu.elements,
          activationElement: ExpoUI.Button(props: submenu.button),
          props: props
        )
      }
    }
  }
}

struct SinglePressContextMenu<ActivationElement: View>: View {
  let elements: [ContextMenuElement]?
  let activationElement: ActivationElement
  let props: ContextMenuProps?

  var body: some View {
    #if !os(tvOS)
    SwiftUI.Menu {
      MenuItems(fromElements: elements, props: props)
    } label: {
      activationElement
    }
    #else
    Text("SinglePressContextMenu is not supported on this platform")
    #endif
  }
}

struct LongPressContextMenu<ActivationElement: View>: View {
  let elements: [ContextMenuElement]?
  let activationElement: ActivationElement
  let props: ContextMenuProps?

  var body: some View {
    activationElement.contextMenu(menuItems: {
      MenuItems(fromElements: elements, props: props)
    })
  }
}

struct LongPressContextMenuWithPreview<ActivationElement: View, Preview: View>: View {
  let elements: [ContextMenuElement]?
  let activationElement: ActivationElement
  let preview: Preview
  let props: ContextMenuProps?

  var body: some View {
    if #available(iOS 16.0, tvOS 16.0, *) {
      activationElement.contextMenu(menuItems: {
        MenuItems(fromElements: elements, props: props)
      }, preview: {
        preview
      })
    } else {
      activationElement.contextMenu(menuItems: {
        MenuItems(fromElements: elements, props: props)
      })
    }
  }
}

struct ContextMenuPreview: ExpoSwiftUI.View, ExpoSwiftUI.WithHostingView {
  @ObservedObject var props: ContextMenuPreviewProps

  var body: some View {
    Children()
  }
}

struct ContextMenuActivationElement: ExpoSwiftUI.View, ExpoSwiftUI.WithHostingView {
  @ObservedObject var props: ContextMenuActivationElementProps

  var body: some View {
    Children()
  }
}

struct ContextMenu: ExpoSwiftUI.View, ExpoSwiftUI.WithHostingView {
  @ObservedObject var props: ContextMenuProps

  var body: some View {
    if props.activationMethod == .singlePress {
      let activationElement = props.children?.filter({
        ExpoSwiftUI.isHostingViewOfType(view: $0, viewType: ContextMenuActivationElement.self)
      })
      SinglePressContextMenu(
        elements: props.elements,
        activationElement: UnwrappedChildren(children: activationElement),
        props: props
      )
    } else {
      let preview = props.children?.filter({
        ExpoSwiftUI.isHostingViewOfType(view: $0, viewType: ContextMenuPreview.self)
      })
      let activationElement = props.children?.filter({
        ExpoSwiftUI.isHostingViewOfType(view: $0, viewType: ContextMenuActivationElement.self)
      })
      if preview?.count ?? 0 > 0 {
        LongPressContextMenuWithPreview(
          elements: props.elements,
          activationElement: UnwrappedChildren(children: activationElement),
          preview: UnwrappedChildren(children: preview),
          props: props
        )
      } else {
        LongPressContextMenu(
          elements: props.elements,
          activationElement: UnwrappedChildren(children: activationElement),
          props: props
        )
      }
    }
  }
}

private func addId(_ id: String?, toMap initialMap: [String: Any]?) -> [String: Any] {
  var newMap = initialMap ?? [:]
  newMap["contextMenuElementID"] = id
  return newMap
}
