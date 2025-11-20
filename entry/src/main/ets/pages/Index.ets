import { util } from '@kit.ArkTS'
import { LengthUnit, promptAction } from '@kit.ArkUI'

@Entry
@ComponentV2
struct Index {
  @Local vm: IndexViewModel = new IndexViewModel()
  amplificationFunction?: (x: number) => number
  @BuilderParam item: (item: listDataSource, index: number) => void = this.placeholderElements


  aboutToAppear(): void {
    // 创建原始数据
    this.vm.dataSource = Array.from<undefined, listDataSource>({ length: 5 }, (v, i) => {
      return {
        id: util.generateRandomUUID(),
        bg: getRandomColor(),
        index: i
      }
    })

    // 获得用于展示的循环长列表
    this.vm.loopList = this.getLoopLongList(this.vm.dataSource, 100)

    this.vm.vmInit()
  }

  getLoopLongList<T>(arr: T[], length: number = 50) {
    // 如果列表本身就很大, 那就直接复制3份返回
    if (arr.length >= length) {
      return [
        ...arr,
        ...arr,
        ...arr,
      ]
    }

    // 保证复制数量为奇数
    let copyNum: number = Math.floor(length / arr.length);
    if (!(copyNum % 2)) {
      copyNum++
    }
    const newArr: T[] = []
    for (let i = 0; i < copyNum; i++) {
      newArr.push(...arr)
    }

    return newArr
  }


  handleScrollStop() {
    const listLength = this.vm.listLength
    const center = this.vm.listCenterIndex

    if (listLength <= 0 || center < 0) {
      return
    }

    const total = this.vm.loopList.length
    // 20为两端安全区, 如果处于安全区, 则移动列表
    const leftGuard = 20
    const rightGuard = total - 20

    // 如果还在安全区中间，什么都不做
    if (center >= leftGuard && center <= rightGuard) {
      return
    }

    // 逻辑索引：映射到 [0, listLength)
    const logicalIndex = ((center % listLength) + listLength) % listLength
    const targetIndex = logicalIndex + listLength * Math.floor(total / listLength / 2)

    // 避免无意义重置
    if (targetIndex === center) {
      return
    }

    const currentArea = this.vm.listItemArea[this.vm.listCenterIndex]
    const currentAreaX = currentArea.position.x as number
    // 拿到偏移数据, 用于定位
    const offset = -currentAreaX

    // 开始重新计算缩放数据
    this.vm.isRelayouting = true

    const indexDifference = this.vm.listCenterIndex - targetIndex

    for (let index = 0; index < this.vm.listItemEffectAttributeArray.length; index++) {
      this.vm.listItemEffectAttributeArray[index].magnify =
        this.amplificationFunction?.((this.vm.listItemArea[index + indexDifference]?.position?.x as number) +
          (this.vm.listItemArea[index + indexDifference]?.width as number / 2)) || 1
    }
    this.vm.isRelayouting = false

    // 下一帧再移动列表
    setTimeout(() => {
      this.vm.scroller.scrollToIndex(
        targetIndex,
        false,
        ScrollAlign.START,
        {
          extraOffset: {
            value: offset,
            unit: LengthUnit.VP
          }
        })
    })

    promptAction.showToast({ message: '列表切换了' })
  }

  // 获取位于中间的第一个item下标
  getListCenterIndex() {
    return Math.floor(this.vm.loopList.length / this.vm.listLength / 2)
  }

  @Builder
  placeholderElements(item: listDataSource, index: number){
    Text('Item' + item.index + '\n' + this.vm.listItemEffectAttributeArray[index]?.magnify?.toFixed(2))
      .height(100)
      .aspectRatio(0.56)
      .backgroundColor(item.bg)
      .scale({
        x: this.vm.listItemEffectAttributeArray[index]?.magnify ?? 1,
        y: this.vm.listItemEffectAttributeArray[index]?.magnify ?? 1,
      })
      .margin({
        left: 18,
        right: 18,
      })
      .border({
        width: 1,
        color: '#a33a3d3a',
        radius: 12
      })
      .onClick(() => {
        this.vm.scroller.scrollToIndex(index, true, ScrollAlign.CENTER)
      })
  }


  build() {
    Column() {

      List({ scroller: this.vm.scroller, initialIndex: this.getListCenterIndex() }) {
        ForEach(this.vm.loopList, (item: listDataSource, index) => {
          ListItem() {
            Column() {
              this.item?.(item,index)
            }
            .justifyContent(FlexAlign.Center)
            .height(150)
            .padding({
              top: 5,
              bottom: 5
            })
          }
          .onAreaChange((ov, nv) => {

            // 更新Area数据
            this.vm.listItemArea[index] = nv

            if (this.vm.isRelayouting) {
              return
            }

            const posX = nv.position.x as number
            const width = nv.width as number

            this.vm.listItemEffectAttributeArray[index] =
              new DockEffectsProperties(this.amplificationFunction?.(posX + width/2))
          })
        })
      }
      .width('100%')
      .height(400)
      .friction(1)
      .scrollBar(BarState.Off)
      .listDirection(Axis.Horizontal)
      .edgeEffect(EdgeEffect.None)
      .onScrollIndex((start, end, center) => {
        this.vm.listCenterIndex = center
      })
      .onSizeChange((ov, nv) => {
        // 拿到列表尺寸数据
        this.vm.listSize = nv

        // 创建缩放函数
        const width = nv.width as number
        this.amplificationFunction = createHump(
          1.8,
          1,
          width,
          width / 2
        )
      })
      .onScrollStart(() => {
      })
      .onScrollStop(() => this.handleScrollStop())
    }
    .justifyContent(FlexAlign.Center)
    .height('100%')
    .width('100%')
  }
}

function getRandomColor() {
  return `#80${(~~(Math.random() * 0xffffff)).toString(16).padStart(6, "0")}`;
}


export function createHump(
  maxH: number,
  minH: number,
  width: number = 8, // 总宽度
  center: number = 0
) {
  return (x: number): number => {
    const dx = x - center;

    // 影响范围是 width / 2（左右各一半）
    const half = width / 2;

    // 区间外为最低高度
    if (Math.abs(dx) >= half) {
      return minH;
    }

    // 归一化 cos：在 -half 到 +half 范围走完一个 cos 波峰（从 π 到 0 到 π）
    // 目标：dx = 0 → cos(0) = 1 → max
    //       dx = ±half → cos(±π) = -1 → min
    const t = (1 + Math.cos((Math.PI * dx) / half)) / 2;

    // 映射到 [minH, maxH]
    return minH + (maxH - minH) * t;
  };
}


interface listDataSource {
  id: string
  bg: string
  index?: number
}

interface IDockEffectsProperties {
  magnify?: number,
  margin?: number
}

@ObservedV2
class DockEffectsProperties implements IDockEffectsProperties {
  @Trace magnify: number = 1
  @Trace margin?: number = 0

  constructor(magnify?: number, margin?: number) {
    this.magnify = magnify ?? this.magnify
    this.margin = margin ?? this.margin
  }
}



@ObservedV2
class IndexViewModel {
  @Trace listItemEffectAttributeArray: DockEffectsProperties[] = []
  @Trace scroller: ListScroller = new ListScroller()
  @Trace dataSource: listDataSource[] = []
  @Trace loopList: listDataSource[] = []
  @Trace isRelayouting: boolean = false
  listSize?: SizeOptions
  listLength: number = 0
  listCenterIndex: number = -1
  listItemArea: Area[] = []
  amplificationFunction?: (x: number) => number

  vmInit(){
    // 获得原始数组长度
    this.listLength = this.dataSource.length

    // 创建缩放效果属性数组
    this.listItemEffectAttributeArray =
      Array.from<undefined, DockEffectsProperties>({ length: this.loopList.length }, () => {
        return new DockEffectsProperties()
      })
  }
}

