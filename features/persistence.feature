Feature: Persistence model
    This feature defines the persistence model of ROD.
  Background:
    Given the library works in development mode
    And the class space is cleared
    And the model is connected with the default database
    And a class Fred has an age field of type integer
    And a class Fred has a sex field of type string with flat index

  Scenario Outline: Persistence of unstored changes
      If there are any changes made to the object after it has
      been persisted, they are lost when the database is closed.
    When database is created
    And I create a Fred
    And his age is '<init_age>'
    And I store him in the database
    And his age is '<grown_age>'
    And I reopen database for reading
    Then there should be 1 Fred
    And the age of the first Fred should be '<init_age>'

    Examples:
      | init_age  | grown_age |
      | 2         | 3         |
      | 8         | 28        |

  Scenario Outline: Store a few Freds of different sexes. Count restored by sex.
    When database is created
    And I create a Fred
    And his sex is '<sex1>'
    And I store him in the database
    And I create another Fred
    And his sex is '<sex2>'
    And I store him in the database
    And I create another Fred
    And his sex is '<sex3>'
    And I store him in the database
    And I reopen database for reading
    Then database should be opened for reading
    And there should be <count1> Fred(s) with 'male' sex
    And there should be <count2> Fred(s) with 'female' sex

    Examples:
      | sex1  | sex2  | sex3    | count1  | count2  |
      | female| male  | female  | 1       | 2       |
      | male  | male  | female  | 2       | 1       |

  Scenario: class with every type of field and association
      Rod should allow to store in the DB instances of a class
      having fields of each type
    Given the class space is cleared
    And the model is connected with the default database
    And a class Caveman has a name field of type string
    And a class Caveman has an age field of type integer
    And a class Caveman has an identifier field of type ulong
    And a class Caveman has a height field of type float
    And a class Caveman has a account_balance field of type float
    And a class Automobile has a name field of type string
    And a class Caveman has one automobile
    And a class Dog has a nickname field of type string
    And a class Caveman has many dogs
    When database is created
    And I create an Automobile
    And its name is 'Prehistoric car'
    And I store it in the database
    And I create a Dog
    And its nickname is 'Snoopy'
    And I store it in the database
    And I create a Caveman
    And his name is 'Fred'
    And his age is '25'
    And his identifier is '111222333'
    And his height is '1.86'
    And his account_balance is '-0.00000001'
    And his automobile is the first Automobile created
    And his dogs contain the first Dog created
    And I store him in the database
    And I reopen database for reading
    Then there should be 1 Caveman
    And there should be 1 Dog
    And there should be 1 Automobile
    And the name of the first Caveman should be 'Fred'
    And the age of the first Caveman should be '25'
    And the identifier of the first Caveman should be '111222333'
    And the height of the first Caveman should be '1.86'
    And the account_balance of the first Caveman should be '-0.00000001'
    And the automobile of the first Caveman should be equal to the first Automobile
    And the first of dogs of the first Caveman should be equal to the first Dog
