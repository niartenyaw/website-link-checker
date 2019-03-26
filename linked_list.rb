class LinkedList
  attr_reader :length
  def initialize
    @first = Node.new(nil)
    @last = Node.new(nil)
    @first.next = @last
    @last.prev = @first
    @length = 0
  end

  def enqueue(val)
    node = Node.new(val)

    last.next = node
    node.prev = last.next

    node.next = last
    last.prev = node

    @length += 1

    node.value
  end

  def dequeue
    node = first.next
    first.next = node.next
    first.next.prev = first
    node.prev = nil
    node.next = nil

    @length -= 1

    node.value
  end

  def empty?
    length == 0
  end

  private

  attr_reader :first, :last
end

class Node
  attr_accessor :next, :prev
  attr_reader :value

  def initialize(value)
    @next = nil
    @prev = nil
    @value = value
  end
end
