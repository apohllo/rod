Feature: collection proxy specification

  Scenario: appending items
    Given the initial size of the collection proxy is 10
    When I append a new item 10 times
    Then the size of the collection proxy should be 20
    And the collection proxy should behave like an array

    When I append a new item 10 times
    Then the size of the collection proxy should be 30
    And the collection proxy should behave like an array

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

  Scenario: modifying collection during interation
    Given the initial size of the collection proxy is 5
    # Can't figure out anything better.
    Then an exception should be raised when the collection is modified during iteration

  Scenario: fast intersection computing
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string
    And a class Automobile has a name field of type string
    And a class Caveman has many automobiles
    When the database is created
    And I create an Automobile
    And its name is 'Car 1'
    And I store it in the database
    And I create another Automobile
    And its name is 'Car 2'
    And I store it in the database
    And I create another Automobile
    And its name is 'Car 3'
    And I store it in the database
    And I create another Automobile
    And its name is 'Car 4'
    And I store it in the database
    And I create another Automobile
    And its name is 'Car 5'
    And I store it in the database
    And I create another Automobile
    And its name is 'Car 6'
    And I store it in the database
    And I create another Automobile
    And its name is 'Car 7'
    And I store it in the database
    And I create a Caveman
    And his name is 'Fred'
    # The automobiles have to be in the creation order, since this is assumed by the
    # fast intersection computation routine.
    And his automobiles contain the first Automobile created
    And his automobiles contain the second Automobile created
    And his automobiles contain the third Automobile created
    And his automobiles contain the fourth Automobile created
    And I store him in the database
    And I create another Caveman
    And his name is 'Bill'
    And his automobiles contain the third Automobile created
    And his automobiles contain the fourth Automobile created
    And his automobiles contain the fifth Automobile created
    And his automobiles contain the sixth Automobile created
    And his automobiles contain the seventh Automobile created
    And I store him in the database
    And I reopen database for reading
    Then there should be 2 Caveman(s)
    And there should be 7 Automobile(s)
    And the first Caveman should have 4 automobiles
    And the second Caveman should have 5 automobiles
    And the intersection size of automobiles of the first and the second Caveman should equal 2

    When the database is created
    And I create an Automobile
    And its name is 'Car 1'
    And I store it in the database
    And I create another Automobile
    And its name is 'Car 2'
    And I store it in the database
    And I create another Automobile
    And its name is 'Car 3'
    And I store it in the database
    And I create another Automobile
    And its name is 'Car 4'
    And I store it in the database
    And I create another Automobile
    And its name is 'Car 5'
    And I store it in the database
    And I create another Automobile
    And its name is 'Car 6'
    And I store it in the database
    And I create another Automobile
    And its name is 'Car 7'
    And I store it in the database
    And I create a Caveman
    And his name is 'Fred'
    And his automobiles contain the first Automobile created
    And his automobiles contain the fifth Automobile created
    And his automobiles contain the sixth Automobile created
    And his automobiles contain the seventh Automobile created
    And I store him in the database
    And I create another Caveman
    And his name is 'Bill'
    And his automobiles contain the first Automobile created
    And his automobiles contain the second Automobile created
    And his automobiles contain the third Automobile created
    And his automobiles contain the sixth Automobile created
    And I store him in the database
    And I reopen database for reading
    Then there should be 2 Caveman(s)
    And there should be 7 Automobile(s)
    And the first Caveman should have 4 automobiles
    And the second Caveman should have 4 automobiles
    And the intersection size of automobiles of the first and the second Caveman should equal 2
