Feature: collection proxy specification

  @wip
  Scenario: appending items
    Given the initial size of the collection proxy is 10
    When I append a new item 10 times
    Then the size of the collection proxy should be 20
    And the collection proxy should behave like an array

    When I append a new item 10 times
    Then the size of the collection proxy should be 30
    And the collection proxy should behave like an array

  @wip
  Scenario: inserting items
    Given the initial size of the collection proxy is 10
    When I insert a new item at position 0
    Then the size of the collection proxy should be 11
    And the collection proxy should behave like an array
    When I insert a new item at position 11
    Then the size of the collection proxy should be 12
    And the collection proxy should behave like an array
    When I insert a new item at position 5
    Then the size of the collection proxy should be 13
    And the collection proxy should behave like an array
    When I insert an item with rod_id = 1 at position 5 3 times
    Then the size of the collection proxy should be 16
    And the collection proxy should behave like an array

  @wip
  Scenario: deleting items
    Given the initial size of the collection proxy is 5
    When I delete an item at position 0 2 times
    Then the size of the collection proxy should be 3
    And the collection proxy should behave like an array
    When I delete an item with rod_id = 3
    Then the size of the collection proxy should be 2
    And the collection proxy should behave like an array
    When I delete an item with rod_id = 3
    Then the size of the collection proxy should be 2
    And the collection proxy should behave like an array
    When I delete an item with rod_id = 4
    Then the size of the collection proxy should be 1
    And the collection proxy should behave like an array
    When I delete an item at position 1
    Then the size of the collection proxy should be 1
    And the collection proxy should behave like an array
    When I delete an item at position 0
    Then the collection proxy should be empty
    And the collection proxy should behave like an array

  @wip
  Scenario: deleting and inserting items
    Given the initial size of the collection proxy is 5
    When I delete an item with rod_id = 1
    Then the size of the collection proxy should be 4
    And the collection proxy should behave like an array
    When I insert a new item at position 0
    Then the size of the collection proxy should be 5
    And the collection proxy should behave like an array
    When I insert an item with rod_id = 6 at position 1
    Then the size of the collection proxy should be 6
    And the collection proxy should behave like an array
    When I delete an item at position 2
    Then the size of the collection proxy should be 5
    And the collection proxy should behave like an array
    When I insert a new item at position 2
    Then the size of the collection proxy should be 6
    And the collection proxy should behave like an array
    When I delete an item with rod_id = 6
    Then the size of the collection proxy should be 4
    And the collection proxy should behave like an array
    When I delete an item at position 1
    Then the size of the collection proxy should be 3
    And the collection proxy should behave like an array
    When I delete an item at position 0
    Then the size of the collection proxy should be 2
    And the collection proxy should behave like an array
    When I delete an item at position 0
    Then the size of the collection proxy should be 1
    And the collection proxy should behave like an array
    When I delete an item at position 0
    Then the size of the collection proxy should be 0
    And the collection proxy should behave like an array
    When I insert a new item at position 0
    Then the size of the collection proxy should be 1
    And the collection proxy should behave like an array

  @wip
  Scenario: deleting and appending items
    Given the initial size of the collection proxy is 5
    When I append a new item 5 times
    Then the size of the collection proxy should be 10
    And the collection proxy should behave like an array
    When I delete an item at position 0
    Then the size of the collection proxy should be 9
    And the collection proxy should behave like an array
    When I delete an item with rod_id = 6
    Then the size of the collection proxy should be 8
    And the collection proxy should behave like an array
    When I append a new item
    Then the size of the collection proxy should be 9
    And the collection proxy should behave like an array

  @wip
  Scenario: inserting, deleting and appending items
    Given the initial size of the collection proxy is 5
    When I append a new item 5 times
    Then the size of the collection proxy should be 10
    And the collection proxy should behave like an array
    When I insert a new item at position 2 3 times
    Then the size of the collection proxy should be 13
    And the collection proxy should behave like an array
    When I insert an item with rod_id = 6 at position 12
    Then the size of the collection proxy should be 14
    And the collection proxy should behave like an array
    When I insert a new item at position 0
    Then the size of the collection proxy should be 15
    And the collection proxy should behave like an array
    When I delete an item with rod_id = 1
    Then the size of the collection proxy should be 14
    And the collection proxy should behave like an array
    When I delete an item with rod_id = 6
    Then the size of the collection proxy should be 12
    And the collection proxy should behave like an array
    When I delete an item with rod_id = 6
    Then the size of the collection proxy should be 12
    And the collection proxy should behave like an array
    When I delete an item at position 5 2 times
    Then the size of the collection proxy should be 10
    And the collection proxy should behave like an array
    When I insert a new item at position 0 5 times
    Then the size of the collection proxy should be 15
    And the collection proxy should behave like an array
    When I delete an item at position 10 5 times
    Then the size of the collection proxy should be 10
    And the collection proxy should behave like an array
    When I append a new item 5 times
    Then the size of the collection proxy should be 15
    And the collection proxy should behave like an array
    When I delete an item at position 5 15 times
    Then the size of the collection proxy should be 5
    And the collection proxy should behave like an array
    When I delete an item at position 0 5 times
    Then the collection proxy should be empty
    And the collection proxy should behave like an array
